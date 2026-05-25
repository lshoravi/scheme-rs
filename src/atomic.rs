use std::sync::{
    Arc,
    atomic::{AtomicUsize, Ordering},
};

use scheme_rs_macros::bridge;

use crate::{
    exceptions::Exception,
    gc::{OpaqueGcPtr, Trace},
    records::{Record, RecordTypeDescriptor, SchemeCompatible, rtd},
    value::Value,
};

// Safety: Value is #[repr(transparent)] over *const (), which is pointer-sized,
// so it has the same size as usize on 64-bit platforms.
//
// GC limitation: storing a Value as raw bits bypasses the GC's reference
// tracking. This is safe for values that are never collected (e.g. interned
// symbols, fixnums, booleans). Storing heap-allocated values (strings, vectors,
// closures) may lead to use-after-free if the GC collects them while only
// referenced from an AtomicBox.

fn val_to_bits(v: &Value) -> usize {
    unsafe { std::mem::transmute_copy(v) }
}

fn bits_to_val(bits: usize) -> Value {
    unsafe { std::mem::transmute_copy(&bits) }
}

#[derive(Debug)]
pub struct AtomicBox {
    inner: AtomicUsize,
}

unsafe impl Trace for AtomicBox {
    unsafe fn visit_children(&self, _visitor: &mut dyn FnMut(OpaqueGcPtr)) {}

    unsafe fn finalize(&mut self) {
        unsafe {
            std::ptr::drop_in_place(self as *mut Self);
        }
    }
}

impl SchemeCompatible for AtomicBox {
    fn rtd() -> Arc<RecordTypeDescriptor> {
        rtd!(
            name: "atomic-box",
            opaque: true,
            sealed: true,
        )
    }
}

#[bridge(name = "make-atomic-box", lib = "(srfi :230)")]
pub async fn make_atomic_box(val: &Value) -> Result<Vec<Value>, Exception> {
    let ab = AtomicBox {
        inner: AtomicUsize::new(val_to_bits(val)),
    };
    Ok(vec![Value::from(Record::from_rust_type(ab))])
}

#[bridge(name = "atomic-box-ref", lib = "(srfi :230)")]
pub async fn atomic_box_ref(box_val: &Value) -> Result<Vec<Value>, Exception> {
    let ab = box_val.try_to_rust_type::<AtomicBox>()?;
    let bits = ab.inner.load(Ordering::SeqCst);
    Ok(vec![bits_to_val(bits)])
}

#[bridge(name = "atomic-box-set!", lib = "(srfi :230)")]
pub async fn atomic_box_set(box_val: &Value, new_val: &Value) -> Result<Vec<Value>, Exception> {
    let ab = box_val.try_to_rust_type::<AtomicBox>()?;
    ab.inner.store(val_to_bits(new_val), Ordering::SeqCst);
    Ok(vec![])
}

#[bridge(name = "atomic-box-swap!", lib = "(srfi :230)")]
pub async fn atomic_box_swap(box_val: &Value, new_val: &Value) -> Result<Vec<Value>, Exception> {
    let ab = box_val.try_to_rust_type::<AtomicBox>()?;
    let old = ab.inner.swap(val_to_bits(new_val), Ordering::SeqCst);
    Ok(vec![bits_to_val(old)])
}

#[bridge(name = "atomic-box-compare-and-swap!", lib = "(srfi :230)")]
pub async fn atomic_box_compare_and_swap(
    box_val: &Value,
    expected: &Value,
    desired: &Value,
) -> Result<Vec<Value>, Exception> {
    let ab = box_val.try_to_rust_type::<AtomicBox>()?;
    let prev = ab.inner.compare_exchange(
        val_to_bits(expected),
        val_to_bits(desired),
        Ordering::SeqCst,
        Ordering::SeqCst,
    );
    let actual = match prev {
        Ok(v) | Err(v) => v,
    };
    Ok(vec![bits_to_val(actual)])
}
