use std::sync::{Arc, Mutex};

use futures::future::BoxFuture;
use scheme_rs_macros::bridge;
use tokio::sync::oneshot;

use crate::{
    exceptions::Exception,
    gc::{Trace, OpaqueGcPtr},
    proc::{Application, AsyncBridgePtr, ContBarrier, Procedure},
    records::{RecordTypeDescriptor, SchemeCompatible, rtd},
    runtime::Runtime,
    value::Value,
};

#[derive(Debug)]
pub struct ResumeSender(Arc<Mutex<Option<oneshot::Sender<Vec<Value>>>>>);

unsafe impl Trace for ResumeSender {
    unsafe fn visit_children(&self, _visitor: &mut dyn FnMut(OpaqueGcPtr)) {}

    unsafe fn finalize(&mut self) {
        unsafe {
            std::ptr::drop_in_place(self as *mut Self);
        }
    }
}

impl SchemeCompatible for ResumeSender {
    fn rtd() -> Arc<RecordTypeDescriptor> {
        rtd!(
            name: "resume-sender",
            opaque: true,
            sealed: true,
        )
    }
}

fn resume_impl<'a>(
    _runtime: &'a Runtime,
    env: &'a [Value],
    args: &'a [Value],
    _rest_args: &'a [Value],
    _barrier: &'a mut ContBarrier<'_>,
    k: Value,
) -> BoxFuture<'a, Application> {
    Box::pin(async move {
        let sender = env[0].try_to_rust_type::<ResumeSender>().unwrap();
        let thunk: Procedure = args[0].clone().try_into().unwrap();
        let result = thunk
            .call(&[], &mut ContBarrier::new())
            .await
            .unwrap_or_default();
        if let Some(tx) = sender.0.lock().unwrap().take() {
            let _ = tx.send(result);
        }
        let k: Procedure = k.try_into().unwrap();
        Application::new(k, vec![])
    })
}

#[bridge(name = "%perform-operation-block", lib = "(fibers operations builtins)")]
pub async fn perform_operation_block(
    block_fn: Procedure,
    flag: &Value,
) -> Result<Vec<Value>, Exception> {
    let (tx, rx) = oneshot::channel::<Vec<Value>>();
    let sender = ResumeSender(Arc::new(Mutex::new(Some(tx))));
    let sender_value = Value::from_rust_type(sender);

    let runtime = block_fn.get_runtime();
    let resume_proc = Procedure::new(
        runtime,
        vec![sender_value],
        resume_impl as AsyncBridgePtr,
        1,
        false,
    );

    block_fn
        .call(
            &[flag.clone(), Value::from(false), Value::from(resume_proc)],
            &mut ContBarrier::new(),
        )
        .await?;

    rx.await
        .map_err(|_| Exception::error("fiber operation cancelled"))
}
