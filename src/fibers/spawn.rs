use std::sync::{Arc, Mutex};

use scheme_rs_macros::{bridge, cps_bridge};
use tokio::task::JoinSet;

use crate::{
    exceptions::Exception,
    gc::{OpaqueGcPtr, Trace},
    proc::{Application, ContBarrier, Procedure},
    records::{RecordTypeDescriptor, SchemeCompatible, rtd},
    runtime::Runtime,
    value::Value,
};

#[derive(Debug)]
pub struct FiberGroup(pub Arc<Mutex<JoinSet<()>>>);

unsafe impl Trace for FiberGroup {
    unsafe fn visit_children(&self, _visitor: &mut dyn FnMut(OpaqueGcPtr)) {}

    unsafe fn finalize(&mut self) {
        unsafe {
            std::ptr::drop_in_place(self as *mut Self);
        }
    }
}

impl SchemeCompatible for FiberGroup {
    fn rtd() -> Arc<RecordTypeDescriptor> {
        rtd!(
            name: "fiber-group",
            opaque: true,
            sealed: true,
        )
    }
}

#[bridge(name = "%make-fiber-group", lib = "(fibers builtins)")]
pub async fn make_fiber_group() -> Result<Vec<Value>, Exception> {
    let group = FiberGroup(Arc::new(Mutex::new(JoinSet::new())));
    Ok(vec![Value::from_rust_type(group)])
}

#[cps_bridge(def = "%spawn-fiber-in-group group task", lib = "(fibers builtins)")]
pub fn spawn_fiber_in_group(
    _runtime: &Runtime,
    _env: &[Value],
    args: &[Value],
    _rest_args: &[Value],
    barrier: &mut ContBarrier,
    k: Value,
) -> Result<Application, Exception> {
    let group = args[0].try_to_rust_type::<FiberGroup>()?;
    let task: Procedure = args[1].clone().try_into()?;
    let saved = barrier.save();
    let join_set = Arc::clone(&group.0);
    join_set.lock().unwrap().spawn(async move {
        let mut barrier = ContBarrier::from(saved);
        let _ = task.call(&[], &mut barrier).await;
    });
    Ok(Application::new(k.try_into().unwrap(), vec![]))
}

#[bridge(name = "%drain-fiber-group", lib = "(fibers builtins)")]
pub async fn drain_fiber_group(group_val: &Value) -> Result<Vec<Value>, Exception> {
    let group = group_val.try_to_rust_type::<FiberGroup>()?;
    // Take the JoinSet out so we can await without holding the lock.
    // New spawns during drain go into the fresh replacement set.
    loop {
        let mut js = std::mem::take(&mut *group.0.lock().unwrap());
        if js.is_empty() {
            break;
        }
        while let Some(result) = js.join_next().await {
            if let Err(e) = result {
                if e.is_panic() {
                    return Err(Exception::error("spawned fiber panicked"));
                }
            }
        }
        // Loop again in case fibers spawned more fibers during drain.
    }
    Ok(vec![])
}

#[cps_bridge(def = "%spawn-fiber task", lib = "(fibers builtins)")]
pub fn spawn_fiber(
    _runtime: &Runtime,
    _env: &[Value],
    args: &[Value],
    _rest_args: &[Value],
    barrier: &mut ContBarrier,
    k: Value,
) -> Result<Application, Exception> {
    let task: Procedure = args[0].clone().try_into()?;
    let saved = barrier.save();
    tokio::task::spawn(async move {
        let mut barrier = ContBarrier::from(saved);
        let _ = task.call(&[], &mut barrier).await;
    });
    Ok(Application::new(k.try_into().unwrap(), vec![]))
}

#[bridge(name = "%run-fibers", lib = "(fibers builtins)")]
pub async fn run_fibers(thunk: Procedure) -> Result<Vec<Value>, Exception> {
    let mut result = thunk.call(&[], &mut ContBarrier::new()).await?;
    if result.is_empty() {
        result.push(Value::from(false));
    }
    Ok(result)
}
