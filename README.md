# Tidal · Liquid Lab

Godot **4.7.2** 的 2D 液體模擬小遊戲，無外部套件。

## 執行

用 Godot 4.7.2 匯入 `project.godot`，按 **F6/F5** 執行主場景。

雲端環境：

```bash
export PATH=/workspace/.local/bin:$PATH
export XDG_DATA_HOME=/workspace/.local/share
export XDG_CONFIG_HOME=/workspace/.config
export XDG_CACHE_HOME=/workspace/.cache
cd /workspace/LiquidSimulator_godot
godot --editor --path .
```

圖形編輯器與遊戲視窗需要可用的顯示服務。無顯示器的雲端可執行下列測試。

## 操作

- 在正方形內按住滑鼠左鍵拖曳，快速改變方向可以產生波浪。
- 右側 **Viscosity** 滑桿調整黏稠度：左側接近水，右側接近糖漿。
- **Space** 或 Pause / Play：暫停／繼續。
- **R** 或 Reset liquid：重設容器位置與液體，保留黏稠度設定。

## 場景編輯

物件已預先儲存在 `.tscn`，遊戲執行時不再用 `Node.new()`／`add_child()` 建立介面或液體顯示物件：

- `main.tscn`：主場景、背景、液體 SubViewport／WaterSurface，以及 `Interface` 下的文字、滑桿與按鈕。
- `scenes/container.tscn`：容器玻璃、四壁輪廓、反光與把手；主場景的 `Container` 節點決定起始位置。
- `scenes/liquid_particles.tscn`：486 個預先放置的粒子實例，可直接查看與調整初始位置。
- `scenes/particle.tscn`：共用的 Sprite2D 粒子外觀與漸層材質。

編輯粒子場景後，程式會讀取實際 Sprite2D 的位置作為初始流體狀態；重設也會恢復這些位置。求解器仍使用陣列計算壓力、黏度與碰撞，再同步到粒子節點，保留流體行為。容器物理邊界目前仍是半邊長 185 的正方形；單獨改變輪廓節點不會改變求解器邊界。整合測試預期標準配置為 486 粒子。

## 為什麼使用粒子流體

液體沒有單一最適合的 Godot 內建「液體物件」。`RigidBody2D` 適合剛體，數百個碰撞圓球通常呈現砂粒或彈珠效果，因此本專案使用自訂的粒子流體求解器；`Node2D` 負責呈現，粒子位置、速度與鄰居資料由獨立求解器維護。

- 486 個粒子；120 Hz 固定模擬步長。
- 空間雜湊搜尋鄰居，對稱雙密度鬆弛修正壓力。
- XSPH 速度擴散控制黏滯程度。
- 移動容器以相對壁面速度處理碰撞；粒子保留慣性，呈現晃動、堆積、波浪。
- 牆面使用鏡像粒子的法向排斥壓力，避免碰撞後粒子重疊成直立水柱；邊界不施加黏附力或切向摩擦。液體壓力限制為非負，避免低密度區域產生非預期的拉力。
- SubViewport 密度貼圖加上閾值著色器融合粒子，呈現連續水體。

這是即時遊戲用的近似流體模型，並非工程 CFD。容器採平移、封閉四壁，不支援旋轉或溢出；黏稠度為藝術控制值而非 Pa·s。高速拖曳有速度上限以維持穩定；較慢電腦在大量粒子運算時可能降低模擬速度。

## 驗證

```bash
godot --headless --path . --editor --import
godot --headless --path . --script tests/scene_test.gd
godot --headless --path . --script tests/viscosity_test.gd
godot --headless --path . --script tests/wall_release_test.gd
godot --headless --path . -- --smoke-test
```

黏度測試比較相同初始速度下的相對動能，確認高黏度確實抑制粒子間相對運動。整合測試以兩種黏稠度和持續移動的容器運行 720 次模擬步，確認粒子數、有限數值、容器邊界和實際運動。無視窗測試不代表已人工驗證畫面與滑鼠操作。

牆面回歸測試會先重現左右內壁的直立粒子柱，確認它們在重力下回落；再以 486 個粒子連續晃動容器 2 秒、靜置 8 秒，檢查粒子數值、邊界與高處掛壁殘留。測試涵蓋黏度 0% 和 100%。
