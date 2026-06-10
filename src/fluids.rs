use std::sync::Arc;

use scheme_rs_macros::bridge;

use crate::{
    exceptions::Exception,
    gc::{Gc, Trace},
    lists::List,
    proc::{
        pop_fluid_bindings, Application, ContBarrier, DynStackElem, FluidBindingEntry,
        FluidBindings, Procedure,
    },
    records::{RecordTypeDescriptor, SchemeCompatible, rtd},
    registry::cps_bridge,
    runtime::Runtime,
    value::{Cell, Value},
};

#[derive(Clone, Trace)]
pub struct Fluid {
    cell: Cell,
}

impl std::fmt::Debug for Fluid {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "#<fluid>")
    }
}

impl Fluid {
    pub fn new(default: Value) -> Self {
        Self {
            cell: Cell::new(default),
        }
    }

    pub fn cell(&self) -> &Cell {
        &self.cell
    }
}

impl SchemeCompatible for Fluid {
    fn rtd() -> Arc<RecordTypeDescriptor> {
        rtd!(name: "fluid", sealed: true, opaque: true)
    }
}

#[bridge(name = "make-fluid", lib = "(srfi :226)")]
fn make_fluid(default: &Value) -> Result<Vec<Value>, Exception> {
    Ok(vec![Value::from_rust_type(Fluid::new(default.clone()))])
}

#[bridge(name = "fluid?", lib = "(srfi :226)")]
fn is_fluid(val: &Value) -> Result<Vec<Value>, Exception> {
    Ok(vec![Value::from(
        val.try_to_rust_type::<Fluid>().is_ok(),
    )])
}

#[bridge(name = "fluid-ref", lib = "(srfi :226)")]
fn fluid_ref(val: &Value) -> Result<Vec<Value>, Exception> {
    let fluid = val.try_to_rust_type::<Fluid>()?;
    Ok(vec![fluid.cell().get()])
}

#[bridge(name = "fluid-set!", lib = "(srfi :226)")]
fn fluid_set(fluid_val: &Value, new_val: &Value) -> Result<Vec<Value>, Exception> {
    let fluid = fluid_val.try_to_rust_type::<Fluid>()?;
    fluid.cell().set(new_val.clone());
    Ok(vec![])
}

#[cps_bridge(def = "%with-fluids fluids vals thunk", lib = "(srfi :226)")]
pub fn with_fluids_internal(
    runtime: &Runtime,
    _env: &[Value],
    k: Procedure,
    args: &[Value],
    _rest_args: &[Value],
    barrier: &mut ContBarrier,
) -> Result<Application, Exception> {
    let [fluids_val, vals_val, thunk_val] = args else {
        return Err(Exception::wrong_num_of_args(3, args.len()));
    };

    let thunk: Procedure = thunk_val.clone().try_into()?;

    let fluids_vec = List::try_from(fluids_val)?.into_vec();
    let vals_vec = List::try_from(vals_val)?.into_vec();

    if fluids_vec.len() != vals_vec.len() {
        return Err(Exception::error(format!(
            "with-fluids: expected {} values, got {}",
            fluids_vec.len(),
            vals_vec.len()
        )));
    }

    let mut entries = Vec::with_capacity(fluids_vec.len());
    for (fluid_val, new_val) in fluids_vec.iter().zip(vals_vec.iter()) {
        let fluid: Gc<Fluid> = fluid_val.try_to_rust_type::<Fluid>()?;
        let old_val = fluid.cell().get();
        fluid.cell().set(new_val.clone());
        entries.push(FluidBindingEntry {
            fluid,
            saved_val: old_val,
            bound_val: new_val.clone(),
        });
    }

    barrier.push_dyn_stack(DynStackElem::FluidBindings(FluidBindings { entries }));

    let pop_k = Procedure::new_cont(
        runtime.clone(),
        vec![Value::from(k)],
        pop_fluid_bindings,
        0,
        true,
        barrier,
    );

    Ok(Application::new(thunk, Some(pop_k), Vec::new()))
}
