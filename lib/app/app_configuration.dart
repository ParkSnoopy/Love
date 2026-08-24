abstract final class AppConfiguration {
  static const appThemeModeKey = 'app_theme_mode';
  static const customThemeBaseKey = 'custom_theme_base';
  static const customThemePrimaryKey = 'custom_theme_primary';
  static const appLocaleCodeKey = 'app_locale_code';
  static const readerFontTypeKey = 'reader_font_type';
  static const readerFontSizeKey = 'reader_font_size';
  static const readerLineSpacingKey = 'reader_line_spacing';
  static const uiScaleKey = 'ui_scale';
  static const readerFontWeightKey = 'reader_font_weight';
  static const readerBookIdKey = 'reader_book_id';
  static const readerChapterKey = 'reader_chapter';
  static const activeBibleIdKey = 'active_bible_id';
  static const activeCommentaryIdKey = 'active_commentary_id';
  static const activeCommentaryFileKey = 'active_commentary_file';
  static const activeCommentaryNameKey = 'active_commentary_name';

  static const appThemeModeDefault = 0;
  static const customThemeBaseDefault = 0;
  static const customThemePrimaryDefault = 0xFFCC785C;
  static const readerFontTypeDefault = 1;
  static const readerFontSizeDefault = 18.0;
  static const readerLineSpacingDefault = 1.5;
  static const uiScaleDefault = 1.0;
  static const readerFontWeightDefault = 'normal';
  static const readerBookIdDefault = 1;
  static const readerChapterDefault = 1;

  static const defaults = <String, Object?>{
    appThemeModeKey: appThemeModeDefault,
    customThemeBaseKey: customThemeBaseDefault,
    customThemePrimaryKey: customThemePrimaryDefault,
    readerFontTypeKey: readerFontTypeDefault,
    readerFontSizeKey: readerFontSizeDefault,
    readerLineSpacingKey: readerLineSpacingDefault,
    uiScaleKey: uiScaleDefault,
    readerFontWeightKey: readerFontWeightDefault,
    readerBookIdKey: readerBookIdDefault,
    readerChapterKey: readerChapterDefault,
  };
}
