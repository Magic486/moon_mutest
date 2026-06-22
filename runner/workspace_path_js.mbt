///|
#module("node:path")
extern "js" fn node_path_join(left : String, right : String) -> String = "join"

///|
#module("node:path")
extern "js" fn node_path_dirname(path : String) -> String = "dirname"

///|
#module("node:path")
extern "js" fn node_path_normalize(path : String) -> String = "normalize"

///|
#module("node:path")
extern "js" fn node_path_resolve(path : String) -> String = "resolve"
