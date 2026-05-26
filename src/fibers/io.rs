use std::os::fd::RawFd;

use scheme_rs_macros::bridge;

use crate::{
    exceptions::Exception,
    ports::Port,
    proc::{ContBarrier, Procedure},
    value::Value,
};

struct FdWrapper(RawFd);

impl std::os::fd::AsRawFd for FdWrapper {
    fn as_raw_fd(&self) -> RawFd {
        self.0
    }
}

#[bridge(name = "%wait-port-readable-then-resume", lib = "(fibers io-wakeup builtins)")]
pub async fn wait_port_readable_then_resume(
    port: &Value,
    resume_thunk: Procedure,
) -> Result<Vec<Value>, Exception> {
    let port: Port = port.clone().try_into()?;
    let fd = port
        .raw_fd()
        .ok_or_else(|| Exception::error("port does not support raw fd access"))?;

    let async_fd = tokio::io::unix::AsyncFd::new(FdWrapper(fd))
        .map_err(|e| Exception::error(format!("cannot watch fd: {e}")))?;

    tokio::task::spawn(async move {
        if let Ok(_guard) = async_fd.readable().await {
            let _ = resume_thunk.call(&[], &mut ContBarrier::new()).await;
        }
    });

    Ok(vec![])
}

#[bridge(name = "%wait-port-writable-then-resume", lib = "(fibers io-wakeup builtins)")]
pub async fn wait_port_writable_then_resume(
    port: &Value,
    resume_thunk: Procedure,
) -> Result<Vec<Value>, Exception> {
    let port: Port = port.clone().try_into()?;
    let fd = port
        .raw_fd()
        .ok_or_else(|| Exception::error("port does not support raw fd access"))?;

    let async_fd = tokio::io::unix::AsyncFd::new(FdWrapper(fd))
        .map_err(|e| Exception::error(format!("cannot watch fd: {e}")))?;

    tokio::task::spawn(async move {
        if let Ok(_guard) = async_fd.writable().await {
            let _ = resume_thunk.call(&[], &mut ContBarrier::new()).await;
        }
    });

    Ok(vec![])
}
