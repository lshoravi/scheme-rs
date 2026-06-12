//! An object freed by reference counting while parked in the collector's
//! pending cycle list left a dangling entry there (use-after-free). Churning
//! cycles whose lifetimes straddle collection epochs hits that window
//! thousands of times per run; without the purge in free() this crashes
//! intermittently.

use parking_lot::RwLock;
use scheme_rs::gc::{Gc, Trace, init_gc};
use std::collections::VecDeque;

#[derive(Default, Trace)]
struct Cyclic {
    next: Option<Gc<RwLock<Cyclic>>>,
}

fn churn(iters: u64) {
    // Deep enough that pairs outlive an epoch (10k allocs) and get parked.
    const RING: usize = 8192;
    let mut ring: VecDeque<Gc<RwLock<Cyclic>>> = VecDeque::new();
    for _ in 0..iters {
        let a = Gc::new(RwLock::new(Cyclic::default()));
        let b = Gc::new(RwLock::new(Cyclic::default()));
        a.write().next = Some(b.clone());
        b.write().next = Some(a);
        ring.push_back(b);
        if ring.len() > RING {
            // Sever the cycle so members hit rc 0 while possibly parked.
            ring.pop_front().unwrap().write().next = None;
        }
    }
}

#[test]
fn cycle_uaf_churn() {
    init_gc();
    let t = std::thread::spawn(|| churn(5_000_000));
    churn(5_000_000);
    t.join().unwrap();
}
