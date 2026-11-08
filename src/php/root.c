#include "include/root.h"
#ifdef _WIN32
    /* call the function defined in win32-imports.zig instead */
    #define zend_map_ptr_new zend_map_ptr_new_local
    extern void* zend_map_ptr_new_local();
#endif

/* AST constants require the separation of the class's constant table */
void enable_ast_constants(zend_class_entry* ce) {
    ce->ce_flags &= ~ZEND_ACC_CONSTANTS_UPDATED;
    ce->ce_flags |= ZEND_ACC_HAS_AST_CONSTANTS;
    if (ce->type == ZEND_INTERNAL_CLASS && !ZEND_MAP_PTR(ce->mutable_data)) {
        ZEND_MAP_PTR_NEW(ce->mutable_data);
    }
}

/* php_stream_to_zval() cannot be imported into Zig due to the presence of bit fields in php_stream */
void set_zval_stream(zval* zv, const php_stream* strm) {
    php_stream_to_zval((php_stream*) strm, zv);
}

php_stream_context* get_stream_context(const php_stream* strm) {
    return PHP_STREAM_CONTEXT((php_stream*) strm);
}

zend_resource* get_stream_resource(const php_stream* strm) {
    return strm->res;
}

const char* get_stream_path(const php_stream* strm) {
    return strm->orig_path;
}

const zval* get_stream_wrapper_data(const php_stream* strm) {
    return &strm->wrapperdata;
}

const char* get_stream_mode(const php_stream* strm) {
    return strm->mode;
}

uint32_t get_stream_flags(const php_stream* strm) {
    return strm->flags;
}

const php_stream_ops* get_stream_handlers(const php_stream* strm) {
    return strm->ops;
}

php_stream_wrapper* get_stream_wrapper(const php_stream* strm) {
    return strm->wrapper;
}

void set_stream_wrapper(php_stream* strm, const php_stream_wrapper* wrapper) {
    strm->wrapper = (php_stream_wrapper*) wrapper;
}

void set_stream_no_close(php_stream* strm) {
    strm->flags |= PHP_STREAM_FLAG_NO_CLOSE;
}

void get_argument_info(const zend_execute_data* ed, arg_extra_info* info) {
    info->ptr = ZEND_CALL_ARG(ed, 1);
    info->len = ZEND_CALL_NUM_ARGS(ed);
    info->extra = !!(ZEND_CALL_INFO(ed) & ZEND_CALL_HAS_EXTRA_NAMED_PARAMS);
}

uint32_t zend_gc_delref(zend_refcounted_h *p) {
	ZEND_ASSERT(p->refcount > 0);
	ZEND_RC_MOD_CHECK(p);
	return --(p->refcount);
}

uint32_t zval_addref_p(zval* pz) {
	ZEND_ASSERT(Z_REFCOUNTED_P(pz));
	return GC_ADDREF(Z_COUNTED_P(pz));
}
