re_uuid = /^[0-9a-f]{8}(?:-?[0-9a-f]{4}){3}-?[0-9a-f]{12}$/i
is_uuid = (x) -> re_uuid.test x
is_uuid.regexp = re_uuid

module.exports = is_uuid
