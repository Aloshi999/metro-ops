# PARKED SANDBOX — NOT THE PRODUCT

**Status:** Systems R&D / throwaway sandbox only.  
**Engine:** Godot 4.x (see `project.godot`).  
**Path:** `/workspace/metro-ops`

## What this is

War-room decision: the **sellable Metro Ops product path is Unreal Engine 5**, not Godot.

This tree stays as a **parked sandbox** for fast systems experiments (sim tick, Deck viewport, FSR-ish scale tests, aggregate city sims). It is useful reference for gameplay feel and Deck constraints — it is **not** the shipping product codebase.

## What this is not

- Not the Steam / Steam Deck storefront build target
- Not the Nanite / World Partition / Lumen product stack
- Not to be deleted, rewritten into UE5, or treated as source of truth for packaging

## Product home

UE5 product staging lives at:

```
/workspace/metro-ops-ue5/
```

See `PRODUCT.md` there for MVP slice and engine goals.

## Rule for agents / builders

- **Do not delete** `/workspace/metro-ops`.
- **Do not** ship Godot builds as Metro Ops product.
- Prefer documenting findings here, then implementing product features under `/workspace/metro-ops-ue5` once UE5 is installed on a capable machine.
