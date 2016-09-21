extend_native = if process.versions.node < '6.3.1'
  (class_name, native_class_name) ->
    util = require 'util'
    eval "var new_class = (function() {
            function #{class_name} () {
              #{native_class_name}.apply(this, arguments);
            }
            return #{class_name};
          })();
          var base_class = #{native_class_name};"
    util.inherits new_class, base_class
    new_class
else
  (class_name, native_class_name) ->
    eval "class #{class_name} extends #{native_class_name} {};"

module.exports =
  native: extend_native
  error: (class_name) -> extend_native class_name, 'Error'
