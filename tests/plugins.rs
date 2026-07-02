#[cfg(feature = "plugins")]
mod common;

#[cfg(feature = "plugins")]
fn test_plugin_dylib_name() -> &'static str {
    if cfg!(target_os = "macos") {
        "target/debug/libtest_plugin.dylib"
    } else if cfg!(target_os = "windows") {
        "target/debug/test_plugin.dll"
    } else {
        "target/debug/libtest_plugin.so"
    }
}

#[cfg(feature = "plugins")]
#[tokio::test]
async fn load_plugin_and_call_bridges() {
    use scheme_rs::runtime::Runtime;
    use std::path::Path;
    use std::process::Command;

    let plugin_dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/test-plugin");
    let status = Command::new("cargo")
        .args(["build", "--quiet"])
        .current_dir(&plugin_dir)
        .status()
        .expect("failed to build test plugin");
    assert!(status.success(), "test plugin build failed");

    let dylib = plugin_dir.join(test_plugin_dylib_name());
    assert!(dylib.exists(), "test plugin dylib not found at {dylib:?}");

    let rt = Runtime::new();
    let lib = unsafe { libloading::Library::new(&dylib) }.expect("failed to dlopen test plugin");
    unsafe { rt.load_plugin(lib) }.expect("failed to load plugin bridges");

    rt.run_program(Path::new("tests/plugins.scm"))
        .await
        .expect("scheme test failed");
}

#[cfg(feature = "plugins")]
#[tokio::test]
async fn load_same_plugin_twice_is_ok() {
    use scheme_rs::runtime::Runtime;
    use std::path::Path;
    use std::process::Command;

    let plugin_dir = Path::new(env!("CARGO_MANIFEST_DIR")).join("tests/test-plugin");
    Command::new("cargo")
        .args(["build", "--quiet"])
        .current_dir(&plugin_dir)
        .status()
        .expect("failed to build test plugin");

    let dylib = plugin_dir.join(test_plugin_dylib_name());

    let rt = Runtime::new();
    let lib1 = unsafe { libloading::Library::new(&dylib) }.unwrap();
    unsafe { rt.load_plugin(lib1) }.expect("first load failed");

    let lib2 = unsafe { libloading::Library::new(&dylib) }.unwrap();
    unsafe { rt.load_plugin(lib2) }.expect("second load should succeed");

    rt.run_program(Path::new("tests/plugins.scm"))
        .await
        .expect("bridges should work after double load");
}

#[cfg(feature = "plugins")]
#[test]
fn version_constant_matches_crate() {
    assert_eq!(
        scheme_rs::registry::SCHEME_RS_VERSION,
        env!("CARGO_PKG_VERSION"),
    );
}
