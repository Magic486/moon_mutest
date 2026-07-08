///|
#external
priv type JsRemoveOptions

///|
#module("node:fs")
extern "js" fn node_rm_sync(path : String, options : JsRemoveOptions) -> Unit = "rmSync"

///|
extern "js" fn node_remove_options() -> JsRemoveOptions =
  #| () => ({
  #|   recursive: true,
  #|   force: true,
  #|   maxRetries: 8,
  #|   retryDelay: 100
  #| })

///|
extern "js" fn node_remove_tree_retry(
  rm_sync : (String, JsRemoveOptions) -> Unit,
  path : String,
  options : JsRemoveOptions,
) -> Bool =
  #| function(rmSync, path, options) {
  #|   const sleep = ms => {
  #|     const sab = new SharedArrayBuffer(4);
  #|     const view = new Int32Array(sab);
  #|     Atomics.wait(view, 0, 0, ms);
  #|   };
  #|   for (let attempt = 0; attempt < 12; attempt += 1) {
  #|     try {
  #|       rmSync(path, options);
  #|       return true;
  #|     } catch (_) {
  #|       sleep(100);
  #|     }
  #|   }
  #|   return false;
  #| }

///|
fn node_remove_tree(path : String) -> Bool {
  node_remove_tree_retry(node_rm_sync, path, node_remove_options())
}
