use scheme_rs_macros::{bridge, cps_bridge};

use crate::{
    exceptions::Exception,
    proc::{Application, ContBarrier, Procedure},
    runtime::Runtime,
    value::Value,
};

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
    thunk.call(&[], &mut ContBarrier::new()).await
}
