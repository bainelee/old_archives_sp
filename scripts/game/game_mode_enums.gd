extends RefCounted

## 清理 / 建设模式枚举单源；与存档整型值一致，供 game_main 与各 GameMain*Helper 共用（通过 preload 引用本脚本访问枚举）

enum CleanupMode {
	NONE,
	SELECTING,
	CONFIRMING,
	CLEANING,
}

enum ConstructionMode {
	NONE,
	SELECTING_ZONE,
	SELECTING_TARGET,
	CONFIRMING,
}
