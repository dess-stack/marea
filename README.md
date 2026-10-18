# MAREA — Adriatic Aim Suite

Script Roblox : aimbot, ESP et liste des joueurs, avec interface draggable.

## Installation

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/TON_PSEUDO/marea/main/Marea.lua"))()
```

## Touches

| Action | Défaut |
|---|---|
| Ouvrir / fermer le menu | Right Shift |
| Aimbot | E (maintenu) |

Tout est remappable depuis l'interface.

## Fonctionnalités

- **Aimbot** — ciblage par proximité au curseur, FOV, lissage, prédiction, choix de hitbox, check murs / équipe, verrouillage de cible
- **ESP** — boîtes, pseudo, barre de vie, distance, tracers, chams, filtres
- **Joueurs** — spectate, téléportation, HP en direct
- **Divers** — fullbright, watermark, remap, unload

## API

```lua
getgenv().Marea.Config     -- table de config live
getgenv().Marea.Version    -- "1.0.0"
getgenv().Marea.Unload()   -- décharge proprement
```

## Compatibilité

Solara, Delta, Wave, Xeno, Krnl, Synapse, Script-Ware. L'ESP utilise `Drawing` quand l'executor la fournit et bascule sur `BillboardGui` sinon.

## Licence

MIT
