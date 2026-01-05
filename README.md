# PoolService

Easy object pooling

```lua
    local PoolService = require(path.to.PoolService)

    --Make an object pool for every part/model tagged with "Pool"
    --A instance tagged with "PoolChildren" will have a pool made for each of its children
    PoolService:Init()

    local BulletPool = PoolService:GetPool("Bullet")
    
    while true do
        --Grab a bullet
        local Bullet, Return = BulletPool:GetPart()
        
        --Parts/PrimaryParts are anchored when not in-use
        Bullet.Anchored = false
    
        --do whatever
        
        --Return the part to the pool
        Return()
    
        task.wait(1)
    end
```
