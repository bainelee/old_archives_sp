extends Node
## 语言/本地化管理，持久化用户选择的 locale 并应用

const SETTINGS_PATH := "user://settings.cfg"
const KEY_LOCALE := "locale"
const FALLBACK_LOCALE := "zh_CN"


func _ready() -> void:
	_apply_saved_locale()


## 设置语言并持久化
func set_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)
	_save_locale(locale)


## 获取当前 locale
func get_locale() -> String:
	return TranslationServer.get_locale()


func _apply_saved_locale() -> void:
	var saved: String = _load_locale()
	if not saved.is_empty():
		TranslationServer.set_locale(saved)
		return
	var preferred: String = OS.get_locale_language()
	if preferred.begins_with("zh"):
		TranslationServer.set_locale("zh_CN")
	elif preferred.begins_with("en"):
		TranslationServer.set_locale("en")
	else:
		TranslationServer.set_locale(FALLBACK_LOCALE)


func _save_locale(locale: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("locale", KEY_LOCALE, locale)
	cfg.save(SETTINGS_PATH)


func _load_locale() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return ""
	return cfg.get_value("locale", KEY_LOCALE, "")
