use std::time::Duration;

use scheme_rs_macros::bridge;

use crate::{
    exceptions::Exception,
    proc::{ContBarrier, Procedure},
    value::Value,
};

#[bridge(name = "%timer-block-and-resume", lib = "(fibers timers builtins)")]
pub async fn timer_block_and_resume(
    seconds: f64,
    resume: Procedure,
) -> Result<Vec<Value>, Exception> {
    tokio::task::spawn(async move {
        tokio::time::sleep(Duration::from_secs_f64(seconds)).await;
        let _ = resume.call(&[], &mut ContBarrier::new()).await;
    });
    Ok(vec![])
}
