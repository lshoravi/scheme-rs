#![cfg(all(feature = "async", feature = "tokio"))]

#[allow(unused)]
mod common;

use scheme_rs::{exceptions::Exception, proc::Procedure, registry::bridge, value::Value};

// call_sync is only reached from non-worker threads now (hashtable hash/eq
// callbacks are async all the way), so exercise it from one directly: park a
// fresh OS thread inside call_sync until a runtime worker fires the timer.
#[bridge(name = "call-sync-in-thread", lib = "(test)")]
fn call_sync_in_thread(thunk: &Value) -> Result<Vec<Value>, Exception> {
    let thunk: Procedure = thunk.clone().try_into()?;
    let handle = tokio::runtime::Handle::current();
    std::thread::spawn(move || {
        let _guard = handle.enter();
        thunk.call_sync(&[])
    })
    .join()
    .unwrap()
}

// multi_thread is required: this bridge blocks its worker in join() while
// another worker drives the timer that wakes the parked thread.
#[tokio::test(flavor = "multi_thread")]
async fn blockon_pending() {
    use scheme_rs::runtime::Runtime;
    use std::path::Path;

    let rt = Runtime::new();
    rt.run_program(Path::new("tests/blockon_pending.scm"))
        .await
        .expect("Test blockon_pending failed");
}
