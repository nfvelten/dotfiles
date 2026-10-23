// Pure calendar rules, shared by the QML store and deterministic clock tests.
function dateKey(date) {
    function pad(n) { return String(n).padStart(2, "0") }
    return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate())
}
function timestamp(date, time) {
    if (!date || !time) return NaN
    var d = date.split("-"), t = time.split(":")
    return new Date(Number(d[0]), Number(d[1]) - 1, Number(d[2]), Number(t[0]), Number(t[1])).getTime()
}
function startOf(e) { return timestamp(e.date, e.time) }
function endOf(e) {
    var start = startOf(e), end = timestamp(e.endDate || e.date, e.endTime)
    return end > start ? end : start + 2 * 3600000
}
// Time left until an event, as shown on the agenda card and the calendar rows.
function countdown(e, now) {
    var start = startOf(e)
    if (!isFinite(start)) return ""
    if (endOf(e) <= now) return "ended"
    if (start <= now) return "live"
    var minutes = Math.ceil((start - now) / 60000)
    if (minutes < 60) return "in " + minutes + " min"
    if (minutes < 1440) return "in " + Math.floor(minutes / 60) + " h" + (minutes % 60 ? " " + minutes % 60 + " min" : "")
    var days = Math.round(minutes / 1440)
    return days === 1 ? "tomorrow" : "in " + days + " days"
}
function normalize(text) { return String(text || "").normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase().trim() }
function key(e) { return JSON.stringify([e.calendar, e.uid || e.title, e.date, e.time]) }
function duplicateKey(e) { return JSON.stringify([normalize(e.title).replace(/[^a-z0-9]+/g, " ").trim(), startOf(e)]) }
function cancelled(e) { return /cancelled|canceled|postponed|adiad[oa]|cancelad[oa]|suspended/i.test((e.title || "") + " " + (e.status || e.description || "")) }
function favorite(e, config) {
    var entry = (config.events || {})[key(e)]
    if (entry && entry.favorite !== undefined) return !!entry.favorite
    return String(config.keywords || "").split(",").some(function(word) {
        word = normalize(word)
        return word.length > 0 && normalize(e.title).indexOf(word) >= 0
    })
}
function minutesFor(e, config) {
    var entry = (config.events || {})[key(e)]
    if (entry && entry.minutes !== undefined) return Number(entry.minutes)
    return (config.allCalendars || (config.calendars || []).indexOf(e.calendar) >= 0 || favorite(e, config)) ? Number(config.minutes === undefined ? 15 : config.minutes) : -1
}
function upcoming(events, now, config) {
    var seen = {}
    return events.filter(function(e) {
        var id = duplicateKey(e), start = startOf(e)
        if (seen[id] || cancelled(e) || !isFinite(start) || start - now >= 3600000 || endOf(e) <= now) return false
        seen[id] = true
        return true
    }).sort(function(a, b) {
        return Number(favorite(b, config)) - Number(favorite(a, config)) || startOf(a) - startOf(b)
    })
}
function eventUrl(e) {
    var found = String(e.description || "").match(/https?:\/\/[^\s<>"\)]+/i)
    return found ? found[0].replace(/[.,;]+$/, "") : ""
}
// Persist the result before dispatching. Five-minute grace covers resume/scheduler jitter
// without replaying old matches. Snoozes must still exist in a fresh agenda snapshot.
function plan(events, config, previous, now) {
    var state = {fired: {}, snoozes: {}}, notices = [], seen = {}, live = {}
    var weekAgo = now - 7 * 86400000
    Object.keys(previous.fired || {}).forEach(function(k) {
        if (previous.fired[k] > weekAgo) state.fired[k] = previous.fired[k]
    })
    events.forEach(function(e) { live[key(e)] = e })
    Object.keys(previous.snoozes || {}).forEach(function(k) {
        var e = live[k], at = previous.snoozes[k]
        if (e && !cancelled(e) && endOf(e) > now && now - at <= 300000) state.snoozes[k] = at
    })
    if (!config.enabled) return {state: state, notices: notices}
    events.forEach(function(e) {
        var start = startOf(e), id = key(e), canonical = duplicateKey(e)
        if (!isFinite(start) || cancelled(e) || endOf(e) <= now) return
        var snooze = state.snoozes[id]
        if (snooze) {
            if (now >= snooze && !seen[canonical]) {
                notices.push({event: e, snoozed: true})
                seen[canonical] = true
                delete state.snoozes[id]
            }
            return
        }
        var minutes = minutesFor(e, config)
        if (minutes < 0) return
        var times = [minutes]
        if (config.atStart && minutes !== 0) times.push(0)
        times.forEach(function(offset) {
            var due = start - offset * 60000, firedKey = canonical + ":" + offset
            if (state.fired[firedKey] || now < due || now - due > 300000 || now - start > 300000) return
            state.fired[firedKey] = now
            if (!seen[canonical]) {
                seen[canonical] = true
                notices.push({event: e, snoozed: false})
            }
        })
    })
    return {state: state, notices: notices}
}
