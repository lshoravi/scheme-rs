use scheme_rs_macros::bridge;

use crate::{
    exceptions::Exception,
    proc::{ContBarrier, Procedure},
    value::Value,
};

#[bridge(name = "%spawn-fiber", lib = "(fibers builtins)")]
pub async fn spawn_fiber(task: &Value) -> Result<Vec<Value>, Exception> {
    let task: Procedure = task.clone().try_into()?;
    tokio::task::spawn(async move {
        let _ = task.call(&[], &mut ContBarrier::new()).await;
    });
    Ok(vec![])
}

#[bridge(name = "%run-fibers", lib = "(fibers builtins)")]
pub async fn run_fibers(thunk: Procedure) -> Result<Vec<Value>, Exception> {
    thunk.call(&[], &mut ContBarrier::new()).await
}
