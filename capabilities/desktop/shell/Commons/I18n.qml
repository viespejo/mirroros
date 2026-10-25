pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Plural.js" as Plural
import "Numbers.js" as Numbers

// Adapted from Omarchy shell/Commons/I18n.qml at 7075b61c6aaa5d8589f6e816867508fc96dc49d9
// (MIT, Copyright (c) David Heinemeier Hansson). English only: the catalog is
// i18n-en.json next to this file (the keys the shell uses, values unmodified
// from Omarchy default/i18n/en/shell.json). The language file, the locale
// registry, OMARCHY_PATH and right-to-left layouts are not carried over.
// Use as I18n.t("common.search"), with .arg(...) for %1 holes,
// and I18n.tn(key, count).arg(I18n.formatNumber(count)) for an
// entry with plural forms.
QtObject {
  id: root

  readonly property string language: "en"
  readonly property string formatLocale: "en-US"
  readonly property string decimal: "."
  readonly property string zeroDigit: "0"
  readonly property bool rightToLeft: false

  // Reading text() makes blockLoading take effect on the first lookup.
  readonly property var strings: parseCatalog(englishCatalogFile.text())

  function t(key, fallback) {
    var value = root.strings[key]
    if (value && typeof value === "object") value = value.other
    if (typeof value === "string" && value.length > 0) return value
    return fallback !== undefined ? fallback : key
  }

  function tn(key, count, fallback) {
    var value = Plural.pick(root.strings[key], "en", count)
    if (typeof value === "string" && value.length > 0) return value
    return fallback !== undefined ? fallback : key
  }

  function formatNumber(value, decimals) {
    return Numbers.format(value, decimals, root.decimal, root.zeroDigit)
  }

  function parseCatalog(raw) {
    try {
      var parsed = JSON.parse(raw || "{}")
      return (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : ({})
    } catch (e) {
      return ({})
    }
  }

  property FileView englishCatalogFile: FileView {
    path: Quickshell.shellPath("Commons/i18n-en.json")
    printErrors: false
    blockLoading: true
  }
}
