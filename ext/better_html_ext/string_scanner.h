#pragma once

enum string_scanner_context {
  SS_TEXT = 0,
  SS_MARKER,
};

extern VALUE text_symbol,
  percent_symbol,
  marker_start_symbol,
  marker_end_symbol,
  identifier_symbol,
  malformed_symbol
;

struct scan_t {
  const char *string;
  uint32_t cursor;
  uint32_t length;
};

struct string_scanner_t {
  enum string_scanner_context context;

  void *callback_data;
  void (*f_callback)(struct string_scanner_t *ss, VALUE sym, uint32_t length, void *data);

  struct scan_t scan;
};

void Init_better_html_string_scanner(VALUE mBetterHtml);
void string_scanner_init(struct string_scanner_t *tk);
void scan_all(struct string_scanner_t *tk);

extern const rb_data_type_t string_scanner_data_type;
#define StringScanner_Get_Struct(obj, sval) TypedData_Get_Struct(obj, struct string_scanner_t, &string_scanner_data_type, sval)