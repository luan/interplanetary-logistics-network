# Interplanetary Logistics Network

Advanced logistics system for resource sharing across planets

[![Factorio](https://img.shields.io/badge/Factorio-2.0+-blue.svg)](https://factorio.com/)
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
- Items can be requested by any requester chest on other surfaces
- Quality reduces power consumption and transfer time

### Interplanetary Requester Chest

- Configure item requests via logistic slots
- Receives items from provider chests on any surface
- Transfers occur independently of local logistics

## Power & Performance

### Energy Costs

Power consumption varies based on your settings combination:

**Power Cost Presets** (Sending MW / Receiving MW):

- **Free**: 0 MW / 0 MW - No power required
- **Cheap**: 4 MW / 1 MW - For easier gameplay
- **Normal**: 16 MW / 4 MW - Balanced default
- **Expensive**: 40 MW / 10 MW - Challenging
- **Extreme**: 80 MW / 20 MW - Maximum difficulty

**Speed Settings** affect both duration and power:

| Speed Setting  | Duration | Power Multiplier | Energy at Normal Cost |
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
- Overall: 31x efficiency improvement

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

- Research Logistic System technology
- Have Space Science Pack production running
- Establish power generation on target planets/platforms

### Basic Setup

1. Research "Interplanetary Logistics" technology
2. Craft provider and requester chests
3. Place provider chests near item sources
4. Configure requester chests with desired items
5. Ensure adequate power supply for transfers
6. Items will transfer automatically between surfaces

### Optimization

1. Start with normal quality chests and default settings
2. Research speed technologies as you explore planets
3. Upgrade to higher quality chests for efficiency
4. Adjust speed settings based on power availability
