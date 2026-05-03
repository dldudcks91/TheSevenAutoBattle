class_name BattleResult
extends RefCounted

# BATTLE → RESULT 단방향 페이로드.
# BattleSimulator는 보상 가산이나 라운드 진행을 직접 하지 않고 결과만 만들어 emit한다.
# 보상 적용은 battle_phase가 단일 지점에서 RunProgress·Economy를 호출한다.

var won: bool = false
var was_last_round: bool = false
var kills: int = 0
var losses: int = 0
var gold_earned: int = 0
var round_index: int = 0
