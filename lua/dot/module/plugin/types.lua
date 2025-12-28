---@alias dot.module.plugin.ViewModeEnum
---| "home"
---| "profile"
---| "update"
---| "clean"

---@alias dot.module.plugin.TaskStatusEnum
---| "running"
---| "done"
---| "error"

---@class dot.module.plugin.IConfig
---@field public lockfile               string
---@field public root                   string
---@field public ui                     dot.module.plugin.IUIConfig

---@class dot.module.plugin.IUIConfig
---@field public size                   dot.module.plugin.ISize
---@field public border                 string
---@field public title                  string
---@field public icons                  dot.module.plugin.IIcons

---@class dot.module.plugin.ISize
---@field public width                  number
---@field public height                 number

---@class dot.module.plugin.IIcons
---@field public cmd                    string
---@field public dep                    string
---@field public event                  string
---@field public ft                     string
---@field public keys                   string
---@field public lazy                   string
---@field public loaded                 string
---@field public not_loaded             string
---@field public source                 string

---@class dot.module.plugin.IGitInfo
---@field public branch                 string|nil
---@field public commit                 string|nil

---@class dot.module.plugin.ILockEntry
---@field public branch                 string
---@field public commit                 string

---@class dot.module.plugin.ICommitInfo
---@field public hash                   string
---@field public message                string
---@field public time                   string

---@class dot.module.plugin.ITaskState
---@field public name                   string
---@field public status                 dot.module.plugin.TaskStatusEnum
---@field public message                string
---@field public from_commit            string|nil
---@field public to_commit              string|nil
---@field public commits                dot.module.plugin.ICommitInfo[]|nil

---@class dot.module.plugin.ITextSegment
---@field public str                    string
---@field public hl                     string|nil

---@class dot.module.plugin.IKeySpec
---@field public lhs                    string
---@field public rhs                    (string|fun())|nil
---@field public mode                   string|string[]|nil
---@field public desc                   string|nil
---@field public noremap                boolean|nil
---@field public remap                  boolean|nil
---@field public expr                   boolean|nil
---@field public nowait                 boolean|nil

---@class dot.module.plugin.IPluginSpec
---@field public name                   string
---@field public main                   string|nil
---@field public url                    string|nil
---@field public branch                 string|nil
---@field public build                  string|(fun(): nil)|nil
---@field public cond                   (fun(): boolean)|nil
---@field public enabled                boolean|nil
---@field public lazy                   boolean|nil
---@field public event                  string|string[]|nil
---@field public cmd                    string|string[]|nil
---@field public ft                     string|string[]|nil
---@field public keys                   dot.module.plugin.IKeySpec[]|nil
---@field public dependencies           string[]|nil
---@field public opts                   table|(fun(): table)|nil
---@field public config                 (fun(spec: dot.module.plugin.IPluginSpec, opts: table): nil)|nil

---@class dot.module.plugin.IPluginState
---@field public spec                   dot.module.plugin.IPluginSpec
---@field public loaded                 boolean
---@field public load_time              number|nil
---@field public path                   string|nil

---@class dot.module.plugin.IRawSpec
---@field public name                   string
---@field public branch                 string|nil
---@field public main                   string|nil
---@field public cond                   fun(): boolean
