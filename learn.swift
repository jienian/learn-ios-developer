体系一：SwiftUI 布局原理与深度实战
1. 苹果官方三大布局协商法则（The Three-Step Layout Process）
SwiftUI 的布局不是由父视图强制指定子视图的尺寸，而是通过协商机制完成的，共三步：

父视图提供建议尺寸（Parent proposes a size）：父视图告诉子视图：“我有宽 300、高 200 的空间，你想要多少？”

子视图决定自身尺寸（Child decides its size）：子视图根据自己的内容（如文本长度、图片原始大小）决定实际尺寸，并答复父视图：“我只需要宽 150、高 40。”（子视图拥有绝对决定权）

父视图放置子视图（Parent positions the child）：父视图根据对齐方式（.center、.leading 等），把子视图放置在自己的坐标系内。
2. 深入理解 .frame 修饰符（关键避坑点）
在 Android Compose 中，Modifier.size(100.dp) 是直接改变该组件的测量约束；
但在 SwiftUI 中：所有修饰符（Modifier）都是在外面包裹一层新的无形视图！

Text("EE 传感器")
    .background(Color.red)
    .frame(width: 200, height: 100)
    .background(Color.blue)

// 🔍 真实底层行为：
// 1. Text 算出文字需要宽 70、高 20，被第一层 red background 包裹（此时红色只有 70x20）。
// 2. 外层套了一个 200x100 的透明 Frame 容器视图，Text 居中放置在其中。
// 3. 最外层的 blue background 包裹了这个 200x100 的容器（因此蓝色是 200x100）。

响应式弹性约束（对标 Compose 的 fillMaxWidth）
// 对标 Compose: Modifier.fillMaxWidth()
Text("全宽警报")
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color.yellow)

// 复杂范围约束
Text("自适应面板")
    .frame(minWidth: 100, idealWidth: 150, maxWidth: 300, minHeight: 44)

3. 布局优先级与尺寸锁定：layoutPriority & fixedSize
工业场景：在同一行（HStack）中并排展示“硬件长名称”与“实时状态标签”，当屏幕宽度不够时，避免重要信息被压缩省略号（...）
HStack {
    Text("HW-2026-HIGH-PRECISION-SENSOR-REV-B")
        .lineLimit(1)
        .truncationMode(.tail)
        .layoutPriority(0) // 默认优先级：空间不足时优先被挤压裁剪
    
    Spacer()
    
    Text("CRITICAL ERROR")
        .font(.caption)
        .bold()
        .padding(4)

        .background(Color.red)
        .foregroundColor(.white)
        .cornerRadius(4)
        .layoutPriority(1) // 🌟 核心：优先级高，父视图保证优先满足它的完整空间！
}

fixedSize()：阻止父视图向子视图施加压缩建议，强制子视图以其理想尺寸（Ideal Size / wrap_content）渲染，绝不折行或截断。

4. 获取屏幕/父容器几何尺寸：GeometryReader
对标 Compose 的 BoxWithConstraints，用于动态获取当前容器的实际像素宽高和局部/全局坐标系。
fixedSize()：阻止父视图向子视图施加压缩建议，强制子视图以其理想尺寸（Ideal Size / wrap_content）渲染，绝不折行或截断。

4. 获取屏幕/父容器几何尺寸：GeometryReader
对标 Compose 的 BoxWithConstraints，用于动态获取当前容器的实际像素宽高和局部/全局坐标系。
GeometryReader { proxy in
    // proxy.size: 当前可用宽与高
    // proxy.frame(in: .global): 屏幕绝对坐标
    // proxy.frame(in: .local): 本地相对坐标
    VStack {
        Text("当前卡片宽度: \(proxy.size.width, specifier: "%.1f")")
        
        // 动态将图片宽度设定为容器的 50%
        Rectangle()
            .fill(Color.blue)
            .frame(width: proxy.size.width * 0.5, height: 40)
    }
}
.frame(height: 100)

5. iOS 16+ 终极武器：自定义 Layout 协议（对标 Compose 的 Layout(content) { ... }）
如果你需要写一个在换行时自动流式排列的标签栏（Flow Layout），传统写法需要极其恶心的计算；而在 iOS 16 中，只需实现 Layout 协议的两个核心方法：

sizeThatFits（测量总宽高，对标 Compose Measure）

placeSubviews（摆放子视图位置，对标 Compose Layout/Place）
import SwiftUI

/// 简易流式/换行布局容器 (FlowLayout)
struct AutoFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentPoint = CGPoint(x: bounds.minX, y: bounds.minY)
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentPoint.x + size.width > bounds.maxX {
                currentPoint.x = bounds.minX
                currentPoint.y += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: currentPoint, proposal: ProposedViewSize(size))
            currentPoint.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// 优雅使用：
AutoFlowLayout(spacing: 8) {
    ForEach(["EE 焊点虚焊", "ME 结构公差", "阻抗突变", "热失控预警", "CAN通信掉帧"], id: \.self) { tag in
        Text(tag)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
    }
}
