extends Node
## Sound effects. Listens to Game and Market for trades and market events.
## The side hustle calls play() itself for its bounce.

const VOLUME_DB := -8.0
const SOUNDS := {
	"buy": preload("res://assets/sfx/buy.wav"),
	"sell": preload("res://assets/sfx/sell.wav"),
	"crash": preload("res://assets/sfx/crash.wav"),
	"spike": preload("res://assets/sfx/spike.wav"),
	"bounce": preload("res://assets/sfx/bounce.wav"),
}

var players := {}


func _ready() -> void:
	for key in SOUNDS:
		var p := AudioStreamPlayer.new()
		p.stream = SOUNDS[key]
		p.volume_db = VOLUME_DB
		add_child(p)
		players[key] = p
	Game.bought.connect(play.bind("buy"))
	Game.sold.connect(play.bind("sell"))
	Market.event_started.connect(play)


func play(key: String, pitch := 1.0) -> void:
	if players.has(key):
		players[key].pitch_scale = pitch
		players[key].play()
