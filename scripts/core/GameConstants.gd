extends Node

# ============================================================================
# GAME CONSTANTS - Centralne miejsce dla stałych używanych w całej grze
# ============================================================================

# ---- Współczynnik skalowania (288px → 608px playfield) ----
const SCALE_FACTOR = 2.11

# ---- Granice usuwania (px Godot) ----
# Oryginał: 320x200, margines 50px. Przeskalowane × 2.11.
const BOUNDS_LEFT   = -169
const BOUNDS_RIGHT  =  717
const BOUNDS_TOP    = -236
const BOUNDS_BOTTOM =  1080

# ---- Sceny pocisków ----
var enemy_projectile_scene: PackedScene
var player_projectile_scene: PackedScene

# ---- Sceny eksplozji ----
var explosion_scene: PackedScene
var rep_explosion_scene: PackedScene

func _ready():
	# Załaduj sceny pocisków
	enemy_projectile_scene = preload("res://scenes/enemy_projectile/EnemyProjectile.tscn")
	player_projectile_scene = preload("res://scenes/projectile/Projectile.tscn")
	# Załaduj sceny eksplozji
	explosion_scene     = preload("res://scenes/explosions/Explosion.tscn")
	rep_explosion_scene = preload("res://scenes/explosions/RepExplosion.tscn")
