use rand::Rng;
use scheme_rs_macros::bridge;

use crate::{exceptions::Exception, value::Value};

#[bridge(name = "%random-integer", lib = "(fibers internal builtins)")]
pub fn random_integer(n: &Value) -> Result<Vec<Value>, Exception> {
    let n: i64 = n.clone().try_into()?;
    if n <= 0 {
        return Err(Exception::error(
            "random-integer: argument must be positive",
        ));
    }
    let result = rand::rng().random_range(0..n);
    Ok(vec![Value::from(result)])
}
