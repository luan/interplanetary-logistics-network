# Interplanetary Logistics Network

Advanced logistics system for resource sharing across planets and space platforms.

![Interplanetary Logistics Network](thumbnail.png)

[![Factorio](https://img.shields.io/badge/Factorio-2.1-blue.svg)](https://factorio.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

The Interplanetary Logistics Network adds specialized logistics chests that
automatically transfer items between planets and space platforms, creating
interconnected supply chains.

### Key Features

- **Logistic Integration**: Works with existing logistic networks
- **Power Requirements**: Energy costs scale with transfer speed
- **Quality Support**: Higher quality chests reduce power consumption and
  transfer time
- **Research Tree**: Speed improvements unlocked through planetary science packs
- **Configurable Settings**: Adjustable power costs and transfer speeds
- **Automatic Operation**: Set requests and items transfer automatically

## Chest Types

### Interplanetary Provider Chest

- Provides items to the interplanetary network
- Items can be requested by this mod’s requester chests on other surfaces in the same force
- Quality reduces power consumption and transfer time

### Interplanetary Requester Chest

- Configure item requests via logistic slots
- Receives items from provider chests on other surfaces in the same force
- Transfers occur independently of local logistics, including on space platforms
- Select a source planet/platform and optionally a specific provider in the chest panel
- Local robot access is off by default to prevent delivery loops; use inserters or loaders for output
- Enable local robot access in the chest panel for normal buffer behavior: robots can both deliver and collect items
- With robots enabled, request directly from the buffer or unload into another buffer; unloading into a passive provider can create a delivery loop
- Request sections, multipliers, item quality and circuit disable conditions are respected
- Partial stacks work; equipment, blueprints and spoilage survive transfers

## Power & Performance

### Energy Costs

Power consumption varies based on your settings combination:

**Power Cost Presets** (Sending MW / Receiving MW):

- **Free**: 0 MW / 0 MW - No power required
- **Cheap**: 4 MW / 1 MW - For easier gameplay
- **Normal**: 16 MW / 4 MW - Balanced default
- **Expensive**: 40 MW / 10 MW - Challenging
- **Extreme**: 80 MW / 20 MW - Maximum difficulty

**Speed Settings** affect both duration and energy per stack:

| Speed Setting  | Duration | Energy Multiplier | Energy at Normal Cost |
| -------------- | -------- | ---------------- | --------------------- |
| **Ultra-Slow** | 16s      | 0.625x           | 50 MJ                 |
| **Slow**       | 8s       | 0.75x            | 60 MJ                 |
| **Normal**     | 4s       | 1.0x             | 80 MJ                 |
| **Fast**       | 2s       | 2.0x             | 160 MJ                |
| **Ultra-Fast** | 1s       | 5.0x             | 400 MJ                |

### Quality Progression

Quality reduces both power consumption and transfer time:

| Quality       | Energy Efficiency | Speed Bonus | Example Cost\* |
| ------------- | ----------------- | ----------- | -------------- |
| **Normal**    | 100%              | 100%        | 80 MJ / 4.0s   |
| **Uncommon**  | 85% (-15%)        | 90% (-10%)  | 68 MJ / 3.6s   |
| **Rare**      | 70% (-30%)        | 75% (-25%)  | 56 MJ / 3.0s   |
| **Epic**      | 50% (-50%)        | 60% (-40%)  | 40 MJ / 2.4s   |
| **Legendary** | 30% (-70%)        | 40% (-60%)  | 24 MJ / 1.6s   |

_\*Normal speed setting_

---

## Research Progression

Speed improvements are unlocked through planetary science packs:

### Technology Tree

```text
Interplanetary Logistics (Base)
    ↓ Requires Space Science
    │
    ├─ Speed 1 (+15% faster) ← Fulgora (Electromagnetic Science)
    │   │
    │   ├─ Speed 2 (+15% faster) ← Gleba (Agricultural Science)
    │   │   │
    │   │   ├─ Speed 3 (+15% faster) ← Aquilo (Cryogenic Science)
    │   │   │   │
    │   │   │   └─ Speed 4 (+20% faster) ← Promethium Science
```

Each research tier reduces transfer time by 15-20%, with a total
possible reduction of 50.9% when all technologies are researched.

---

## Performance Summary

With legendary quality chests and all research:

- Energy: 24 MJ per stack (70% reduction)
- Time: 0.78 seconds (80.5% faster)

## Configuration

### Startup Settings

| Setting        | Description                            | Default           |
| -------------- | -------------------------------------- | ----------------- |
| Power Cost     | Base power consumption preset          | Normal (16MW/4MW) |
| Transfer Speed | Transfer duration and power multiplier | Normal (4s)       |

### Tips

- Use slower speeds early game to conserve power
- Prioritize quality upgrades for frequently used routes
- Increase speed for critical supply chains as power allows

---

## Getting Started

### Prerequisites

- Factorio and Space Age 2.1 or newer (use ILN 0.4.0 for Factorio 2.0)
- Research Logistic System technology
- Have Space Science Pack production running
- Establish power generation on target planets/platforms

### Basic Setup

1. Research "Interplanetary Logistics" technology
2. Craft **Interplanetary Provider Chests** and **Interplanetary Requester Chests**; vanilla chests do not teleport items
3. Place provider chests near item sources
4. Place a requester on a different planet or platform and configure its item requests and qualities
5. Ensure both endpoints have electric pole coverage and adequate generation; a local roboport is only needed for local robots
6. Items will transfer automatically between surfaces

### Optimization

1. Start with normal quality chests and default settings
2. Research speed technologies as you explore planets
3. Upgrade to higher quality chests for efficiency
4. Adjust speed settings based on power availability


## Transfers and settings

Each request can transfer up to the configured number of stacks (default 1,
maximum 10). Smaller requests and partial provider stacks work too. Energy scales
with the number of items. Both endpoints must pay their share and the transfer
duration must elapse; free power still respects the duration. The slower chest's
quality determines speed. Chest quality reduces its own energy cost, while speed
research reduces time. A second request cannot reserve items already assigned to
another transfer. Items remain at the provider until delivery.

Requests from separate active sections are added after applying their multipliers.
Disabling a section, changing a route or disabling the requester cancels stale
transfers. Items that cannot fit stay at the provider.

**Rocket capacity** defaults to 0 (too heavy for rockets). Set it to 1, 2, 3, 5 or
10 to choose the number of chests per vanilla rocket payload. Chests can also be
crafted directly on a platform. **Chest item stack size** controls inventory
stacking separately, from 1 to 100 (default 10).

## Upgrading

Version 0.4.0 rescans existing chests and removes orphan visual/power helpers.
Pending transfers restart; their items have not left the providers. Local robot
access defaults to off, and circuit disable conditions now also pause
interplanetary transfers. Re-enable local robot access in a requester panel if your
factory deliberately uses buffer behavior. Recipes require Interplanetary Logistics research.

Source filters are copied with entity settings and cloning. Blueprints preserve
source surfaces, but omit specific provider IDs because IDs are local to a save.

## Development

Format with `stylua . --config-path stylua.toml` and lint with
`luacheck . --config .luacheckrc`. Run behavioral checks in Factorio with:

```sh
python3 tests/run.py /path/to/factorio --power normal --stacks 3 --rocket 5
```

The runner uses disposable directories and accelerated simulation ticks. It does
not load or modify player saves. Validate sprites and the requester panel in a
rendered game as well.

See [graphics source](graphics/README.md) for the recovered Blender scene.
