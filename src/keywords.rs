use std::sync::Arc;

use scheme_rs_macros::{Trace, bridge};

use crate::{
    exceptions::Exception,
    records::{RecordTypeDescriptor, SchemeCompatible, rtd},
    strings::WideString,
    symbols::Symbol,
    value::Value,
};

#[derive(Debug, Clone, Trace)]
pub struct Keyword(Symbol);

impl Keyword {
    pub fn new(symbol: Symbol) -> Self {
        Self(symbol)
    }
}

impl SchemeCompatible for Keyword {
    fn rtd() -> Arc<RecordTypeDescriptor> {
        rtd!(name: "keyword", sealed: true, opaque: true)
    }
}

#[bridge(name = "keyword?", lib = "(srfi :88)")]
pub fn keyword_pred(obj: &Value) -> Result<Vec<Value>, Exception> {
    Ok(vec![Value::from(
        obj.cast_to_rust_type::<Keyword>().is_some(),
    )])
}

#[bridge(name = "keyword->string", lib = "(srfi :88)")]
pub fn keyword_to_string(obj: &Value) -> Result<Vec<Value>, Exception> {
    let kw = obj.try_to_rust_type::<Keyword>()?;
    Ok(vec![Value::from(kw.0.to_str().to_string())])
}

#[bridge(name = "string->keyword", lib = "(srfi :88)")]
pub fn string_to_keyword(s: &Value) -> Result<Vec<Value>, Exception> {
    let s: WideString = s.clone().try_into()?;
    let kw = Keyword(Symbol::intern(&s.to_string()));
    Ok(vec![Value::from_rust_type(kw)])
}
