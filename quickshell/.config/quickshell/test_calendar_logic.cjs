const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const test = require('node:test');
const rules = {};
vm.createContext(rules);
vm.runInContext(fs.readFileSync(__dirname + '/CalendarLogic.js', 'utf8'), rules);
function event(extra = {}) { return {calendar:'sports_nba', uid:'game1', title:'🏀 CLE @ PHI', date:'2026-10-31', time:'23:30', endDate:'2026-11-01', endTime:'02:00', ...extra}; }
const game = event(), start = rules.startOf(game);
const config = {enabled:true,minutes:15,calendars:['sports_nba'],events:{}};
const empty = {fired:{},snoozes:{}};
test('countdown shows time left, running and finished games', () => {
    assert.equal(rules.countdown(game,start-45*60000),'in 45 min');
    assert.equal(rules.countdown(game,start-90*60000),'in 1 h 30 min');
    assert.equal(rules.countdown(game,start+60000),'live');
    assert.equal(rules.countdown(game,rules.endOf(game)),'ended');
    assert.equal(rules.countdown(event({time:''}),start),'');
});
test('exact reminder and persisted deduplication after reload', () => {
    const first = rules.plan([game], config, empty, start-15*60000);
    assert.equal(first.notices.length,1);
    assert.equal(rules.plan([game],config,JSON.parse(JSON.stringify(first.state)),start-14*60000).notices.length,0);
});
test('resume grace catches a recent reminder but never a backlog', () => {
    assert.equal(rules.plan([game],config,empty,start-13*60000).notices.length,1);
    assert.equal(rules.plan([game],config,empty,start-8*60000).notices.length,0);
    assert.equal(rules.plan([game],{...config,atStart:true},empty,start+6*60000).notices.length,0);
});
test('simultaneous games survive while cross-feed copies deduplicate', () => {
    const other = event({uid:'game2',title:'🏀 DEN @ OKC'});
    const duplicate = event({uid:'another',calendar:'sports'});
    const result=rules.plan([game,duplicate,other],{...config,calendars:['sports_nba','sports']},empty,start-15*60000);
    assert.equal(result.notices.length,2);
});
test('calendar selection, explicit opt-out, keywords and event override', () => {
    assert.equal(rules.plan([game],{...config,calendars:[]},empty,start-15*60000).notices.length,0);
    assert.equal(rules.plan([game],{...config,calendars:[],keywords:'CLE, Flamengo'},empty,start-15*60000).notices.length,1);
    assert.equal(rules.plan([game],{...config,events:{[rules.key(game)]:{minutes:-1}}},empty,start-15*60000).notices.length,0);
    assert.equal(rules.plan([game],{...config,calendars:[],events:{[rules.key(game)]:{minutes:5}}},empty,start-5*60000).notices.length,1);
});
test('canceled, postponed and all-day events never trigger', () => {
    for (const extra of [{description:'ESPN | Postponed | game'},{status:'CANCELLED'},{time:''}])
        assert.equal(rules.plan([event(extra)],config,empty,start-15*60000).notices.length,0);
});
test('snooze survives reload, cancellation and removal invalidate it', () => {
    const state={fired:{},snoozes:{[rules.key(game)]:start+60000}};
    assert.equal(rules.plan([game],config,state,start).notices.length,0);
    assert.equal(rules.plan([game],config,state,start+60000).notices.length,1);
    assert.equal(rules.plan([],config,state,start+60000).notices.length,0);
    assert.equal(rules.plan([event({description:'Canceled'})],config,state,start+60000).notices.length,0);
});
test('pause respects DND-style suppression without replaying old notifications', () => {
    assert.equal(rules.plan([game],{...config,enabled:false},empty,start-15*60000).notices.length,0);
});
test('changed time is a new occurrence, canceled old snooze is removed', () => {
    const first=rules.plan([game],config,empty,start-15*60000);
    const moved=event({time:'23:45'});
    assert.equal(rules.plan([moved],config,first.state,start).notices.length,1);
});
test('card stays through midnight and disappears at the scheduled end', () => {
    assert.equal(rules.upcoming([game],start+2*3600000,config).length,1);
    assert.equal(rules.upcoming([game],rules.endOf(game),config).length,0);
    assert.equal(rules.dateKey(new Date(2026,10,1)),'2026-11-01');
});
test('optional start reminder is separate from the pre-game reminder', () => {
    const cfg={...config,atStart:true};
    const first=rules.plan([game],cfg,empty,start-15*60000);
    assert.equal(rules.plan([game],cfg,first.state,start).notices.length,1);
});

test('all-calendar default still respects an individual opt-out and zero-minute lead', () => {
    assert.equal(rules.plan([game],{...config,calendars:[],allCalendars:true},empty,start-15*60000).notices.length,1);
    assert.equal(rules.plan([game],{...config,allCalendars:true,events:{[rules.key(game)]:{minutes:-1}}},empty,start-15*60000).notices.length,0);
    assert.equal(rules.plan([game],{...config,minutes:0},empty,start).notices.length,1);
});
