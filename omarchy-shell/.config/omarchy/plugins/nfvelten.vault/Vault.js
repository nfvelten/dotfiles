.pragma library

// Pure helpers for the vault plugin. Kept out of the QML so the path and
// parsing rules can be unit-tested with plain node.

var MONTHS = [
  "Janeiro", "Fevereiro", "Março", "Abril", "Maio", "Junho",
  "Julho", "Agosto", "Setembro", "Outubro", "Novembro", "Dezembro"
]

function pad2(n) {
  return (n < 10 ? "0" : "") + n
}

// `dd-mm-yyyy.md` under `Daily Notes/<Mês>/`, and under an extra `<year>/`
// level from 2026 on — the vault reorganised that year and older notes were
// left where they were.
function dailyNotePath(date) {
  var d = date || new Date()
  var year = d.getFullYear()
  var month = MONTHS[d.getMonth()]
  var file = pad2(d.getDate()) + "-" + pad2(d.getMonth() + 1) + "-" + year + ".md"
  var dir = year >= 2026
    ? "Daily Notes/" + year + "/" + month
    : "Daily Notes/" + month
  return dir + "/" + file
}

function baseName(path) {
  var parts = String(path || "").split("/")
  return parts[parts.length - 1] || ""
}

function noteTitle(path) {
  var name = baseName(path)
  return name.slice(-3) === ".md" ? name.slice(0, -3) : name
}

// Path relative to the vault root, used as the subtitle in the note list so
// two notes with the same name stay distinguishable.
function relativePath(path, vaultPath) {
  var p = String(path || "")
  var root = String(vaultPath || "")
  if (root && p.indexOf(root) === 0) {
    p = p.slice(root.length)
    if (p.charAt(0) === "/") p = p.slice(1)
  }
  var cut = p.lastIndexOf("/")
  return cut === -1 ? "" : p.slice(0, cut)
}

// `find -printf "%T@\t%p\n"` output, newest first. Epoch seconds carry a
// fractional part that Number() handles and parseInt() would truncate.
function parseListing(output, vaultPath, limit) {
  var lines = String(output || "").split("\n")
  var notes = []
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (!line) continue
    var tab = line.indexOf("\t")
    if (tab === -1) continue
    var mtime = Number(line.slice(0, tab))
    var path = line.slice(tab + 1)
    if (!isFinite(mtime) || !path) continue
    notes.push({
      path: path,
      title: noteTitle(path),
      folder: relativePath(path, vaultPath),
      mtime: mtime
    })
  }
  notes.sort(function(a, b) { return b.mtime - a.mtime })
  var max = Number(limit)
  return isFinite(max) && max > 0 ? notes.slice(0, max) : notes
}

// `rg --files-with-matches`, one absolute path per line. Ordered by the
// recency map so search results read like the recent list.
function parseSearch(output, vaultPath, mtimes) {
  var lines = String(output || "").split("\n")
  var notes = []
  for (var i = 0; i < lines.length; i++) {
    var path = lines[i].trim()
    if (!path) continue
    notes.push({
      path: path,
      title: noteTitle(path),
      folder: relativePath(path, vaultPath),
      mtime: (mtimes && mtimes[path]) || 0
    })
  }
  notes.sort(function(a, b) { return b.mtime - a.mtime })
  return notes
}

function mtimeMap(notes) {
  var map = ({})
  for (var i = 0; i < notes.length; i++) map[notes[i].path] = notes[i].mtime
  return map
}

function relativeTime(mtime, now) {
  var then = Number(mtime)
  if (!isFinite(then) || then <= 0) return ""
  var seconds = Math.max(0, Math.floor((now || Date.now() / 1000) - then))
  if (seconds < 60) return "agora"
  var minutes = Math.floor(seconds / 60)
  if (minutes < 60) return minutes + "min"
  var hours = Math.floor(minutes / 60)
  if (hours < 24) return hours + "h"
  var days = Math.floor(hours / 24)
  if (days < 7) return days + "d"
  var weeks = Math.floor(days / 7)
  if (weeks < 5) return weeks + "sem"
  var months = Math.floor(days / 30)
  if (months < 12) return months + "m"
  return Math.floor(days / 365) + "a"
}

// Append a capture under `heading`, before whatever section follows it, so
// the note keeps its shape. A note without the heading grows one at the end.
function appendUnderHeading(text, heading, entry) {
  var body = String(text || "")
  var line = "- " + entry
  var lines = body.split("\n")
  var start = -1
  for (var i = 0; i < lines.length; i++) {
    var trimmed = lines[i].trim()
    if (trimmed.charAt(0) !== "#") continue
    if (trimmed.replace(/^#+\s*/, "") === heading) { start = i; break }
  }
  if (start === -1) {
    var prefix = body.length && body.slice(-1) !== "\n" ? "\n" : ""
    return body + prefix + "\n### " + heading + "\n" + line + "\n"
  }
  // Walk to the end of the section, then back over the blank lines that
  // separate it from the next heading.
  var end = lines.length
  for (var j = start + 1; j < lines.length; j++) {
    if (lines[j].trim().charAt(0) === "#") { end = j; break }
  }
  while (end > start + 1 && lines[end - 1].trim() === "") end--
  lines.splice(end, 0, line)
  return lines.join("\n")
}
