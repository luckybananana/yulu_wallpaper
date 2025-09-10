import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { QuoteDataManager, Quote } from '../common/QuoteDataManager';
import wallpaper from '@ohos.wallpaper'; // 导入壁纸设置API
import image from '@ohos.multimedia.image'; // 导入图像处理API
import display from '@ohos.display'; // 获取屏幕尺寸用于回退
/**
 * 路由参数接口
 */
interface RouterParams {
  index?: number;
  quote?: Quote;
}
/**
 * 文字样式接口
 */
interface TextStyle {
  fontSize: number;
  lineHeight: number;
}
// 添加颜色候选数组，与 web 版本的 COLORS 保持一致
const WALLPAPER_COLORS: string[] = [
  "#E57373", "#F06292", "#BA68C8", "#9575CD", "#7986CB",
  "#64B5F6", "#4DB6AC", "#81C784", "#DCE775", "#FFD54F",
  "#5488BC", "#917C6B", "#AA9F7C", "#A29296", "#515E68"
];
/**
 * 壁纸预览页面
 * 基于wallpaper.html实现壁纸预览、Canvas绘制分层波浪背景、触摸滑动切换语录等功能
 * 并使其样式更接近 web 版本 (壁纸.html)
 */
@Entry
@Component
struct WallpaperPage {
  // 页面状态
  @State quotes: Quote[] = [];
  @State currentQuoteIndex: number = 0;
  @State isControlsVisible: boolean = true;
  @State isLoading: boolean = true;
  @State isShareVisible: boolean = false;
  @State shareState: 'confirm' | 'loading' | 'success' = 'confirm';
  // 触摸相关状态
  @State touchStartX: number = 0;
  @State touchStartY: number = 0;
  // Canvas相关
  private canvasContext?: CanvasRenderingContext2D;
  // 修改：将 canvasWidth 和 canvasHeight 声明为 @State

  @State private canvasWidth: number = 0;
  @State private canvasHeight: number = 0;
  private canvasElement: CanvasRenderingContext2D | null = null;
  // 新增：用于存储当前语录对应的颜色
  @State currentQuoteColor: string = '#4A90E2'; // 默认颜色
  // 服务实例
  private quoteManager = QuoteDataManager.getInstance(getContext(this));
  /**
   * 页面初始化
   */
  async aboutToAppear() {
    console.log('壁纸预览界面加载完成');
    await this.loadQuotes();
    this.initializeIndex();
  }
  /**
   * 加载语录数据
   */
  async loadQuotes() {
    try {
      this.quotes = await this.quoteManager.getAllQuotes();
      console.log('语录数据加载完成:', this.quotes.length, '条');
      // 如果没有语录，使用默认语录
      if (this.quotes.length === 0) {
        const defaultQuote: Quote = {
          id: 'default',
          text: '生活不是等待风暴过去，而是学会在雨中翩翩起舞。',
          tags: [],
          createdAt: new Date().toISOString(),
          updatedAt: new Date().toISOString()
        };
        this.quotes = [defaultQuote];
      }
      this.isLoading = false;
    } catch (error) {
      console.error('加载语录失败:', error);
      // 使用默认语录作为备选
      const defaultQuote: Quote = {
        id: 'default',
        text: '生活不是等待风暴过去，而是学会在雨中翩翩起舞。',
        tags: [],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      };
      this.quotes = [defaultQuote];
      this.isLoading = false;
    }
  }
  /**
   * 新增：根据当前语录索引更新颜色
   */
  private updateCurrentQuoteColor() {
    if (this.quotes.length > 0 && this.currentQuoteIndex >= 0) {
      // 使用取模运算确保索引在颜色数组范围内
      const colorIndex = this.currentQuoteIndex % WALLPAPER_COLORS.length;
      this.currentQuoteColor = WALLPAPER_COLORS[colorIndex];
      console.log(`当前语录索引: ${this.currentQuoteIndex}, 使用颜色: ${this.currentQuoteColor}`);
    } else {
      // 如果没有语录或索引无效，使用默认颜色
      this.currentQuoteColor = '#4A90E2';
    }
  }
  /**
   * 初始化索引
   * 修改：在设置索引后，计算并设置当前语录的颜色
   */
  initializeIndex() {
    const params = router.getParams() as RouterParams;
    if (params) {
      // 优先使用传递的quote参数
      if (params.quote) {
        const quoteIndex = this.quotes.findIndex(q => q.id === params.quote!.id);
        if (quoteIndex >= 0) {
          this.currentQuoteIndex = quoteIndex;
        } else {
          // 如果没找到对应的quote，将传递的quote添加到列表开头
          this.quotes.unshift(params.quote);
          this.currentQuoteIndex = 0;
        }
      } else if (typeof params.index === 'number' &&
        params.index >= 0 && params.index < this.quotes.length) {
        this.currentQuoteIndex = params.index;
      }
    }
    // 新增：根据当前索引设置颜色
    this.updateCurrentQuoteColor();
  }
  /**
   * 十六进制颜色转RGB
   */
  private hexToRgb(hex: string): number[] {
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result ? [
      parseInt(result[1], 16),
      parseInt(result[2], 16),
      parseInt(result[3], 16)
    ] : [0, 0, 0];
  }
  /**
   * 调整颜色亮度（与wallpaper.html的adjustColor函数保持一致）
   */
  private adjustColor(rgb: number[], factor: number = 1.0): number[] {
    const r = rgb[0];
    const g = rgb[1];
    const b = rgb[2];
    return [
      Math.max(0, Math.min(255, Math.floor(r * factor))),
      Math.max(0, Math.min(255, Math.floor(g * factor))),
      Math.max(0, Math.min(255, Math.floor(b * factor)))
    ];
  }
  /**
   * 绘制分层波浪背景（与wallpaper.html的drawLayeredWaves函数保持一致）
   * 修改：接受颜色参数，并确保其行为与web版本完全一致
   */
  private drawLayeredWaves(baseColor: string) { // 修改参数
    if (!this.canvasElement || this.canvasWidth === 0 || this.canvasHeight === 0) return;
    const ctx = this.canvasElement;
    const width = this.canvasWidth;
    const height = this.canvasHeight;
    const baseRgb = this.hexToRgb(baseColor); // 使用传入的颜色
    // 清空画布
    ctx.clearRect(0, 0, width, height);
    // 关键修改：先填充背景色 #E6E6E6，与web版本一致
    ctx.fillStyle = '#E6E6E6';
    ctx.fillRect(0, 0, width, height);
    // 参数设置（与wallpaper.html保持一致）
    const numLayers = 6;
    const baseFromBottom = Math.floor(height * 0.32);
    const gapPerLayer = Math.floor(height * 0.035);
    const baseWavelength = 420;
    const baseAmplitude = 52;
    const step = 6;
    // 绘制6层波浪（从上到下，颜色逐渐加深）
    for (let i = 0; i < numLayers; i++) {
      // 颜色调整（与wallpaper.html的adjust_color逻辑一致）
      const colorFactor = 1 - i * 0.06;
      const adjustedRgb = this.adjustColor(baseRgb, colorFactor);
      // 透明度计算（与wallpaper.html一致：25 + i*38，转换为0-1范围）
      const alpha = Math.min(255, 25 + i * 38) / 255;
      ctx.fillStyle = `rgba(${adjustedRgb[0]}, ${adjustedRgb[1]}, ${adjustedRgb[2]}, ${alpha})`;
      // 波浪参数（与wallpaper.html一致）
      const wavelength = baseWavelength * (1.0 + i * 0.03);
      const amplitude = baseAmplitude * (1.0 + i * 0.05);
      const phase = Math.random() * Math.PI * 2; // 随机相位
      // 层偏移计算（与wallpaper.html一致）
      const layerOffset = height - (baseFromBottom - i * gapPerLayer);
      // 创建波浪路径
      ctx.beginPath();
      // 绘制正弦波（与wallpaper.html逻辑一致）
      const points: number[][] = [];
      for (let x = 0; x <= width; x += step) {
        const y = layerOffset - amplitude * Math.sin(2 * Math.PI * x / wavelength + phase);
        points.push([x, y]);
      }
      // 开始绘制路径
      if (points.length > 0) {
        ctx.moveTo(points[0][0], points[0][1]);
        for (let j = 1; j < points.length; j++) {
          ctx.lineTo(points[j][0], points[j][1]);
        }
      }
      // 封闭路径到底部（与wallpaper.html一致）
      ctx.lineTo(width, height);
      ctx.lineTo(0, height);
      ctx.closePath();
      ctx.fill();
    }
  }
  /**
   * 根据字数自动调整文字样式
   */
  private getTextStyle(content: string): TextStyle {
    const length = content.length;
    if (length <= 15) {
      const style: TextStyle = { fontSize: 32, lineHeight: 1.5 };
      return style;
    } else if (length <= 30) {
      const style: TextStyle = { fontSize: 28, lineHeight: 1.5 };
      return style;
    } else if (length <= 60) {
      const style: TextStyle = { fontSize: 24, lineHeight: 1.6 };
      return style;
    } else if (length <= 100) {
      const style: TextStyle = { fontSize: 20, lineHeight: 1.6 };
      return style;
    } else {
      const style: TextStyle = { fontSize: 18, lineHeight: 1.7 };
      return style;
    }
  }
  /**
   * 切换到指定语录
   * 修改：在切换后更新颜色并重绘
   */
  private switchToQuote(index: number) {
    if (index < 0 || index >= this.quotes.length) return;
    this.currentQuoteIndex = index;
    // 新增：更新颜色
    this.updateCurrentQuoteColor();
    // 重新绘制波浪背景
    setTimeout(() => {
      // 修改：使用当前语录的颜色绘制
      if (this.quotes[index]) {
        this.drawLayeredWaves(this.currentQuoteColor); // 使用动态颜色
      }
    }, 50);
  }
  /**
   * 上一条语录
   */
  private previousQuote() {
    const newIndex = this.currentQuoteIndex > 0 ? this.currentQuoteIndex - 1 : this.quotes.length - 1;
    this.switchToQuote(newIndex);
  }
  /**
   * 下一条语录
   */
  private nextQuote() {
    const newIndex = this.currentQuoteIndex < this.quotes.length - 1 ? this.currentQuoteIndex + 1 : 0;
    this.switchToQuote(newIndex);
  }
  /**
   * 切换控制栏显示/隐藏
   */
  private toggleControls() {
    this.isControlsVisible = !this.isControlsVisible;
  }
  /**
   * 返回上一页
   */
  private goBack() {
    router.back();
  }
  /**
   * 设置壁纸 - 实现真正的系统壁纸设置功能
   */
  private async setWallpaper() {
    try {
      console.log('开始设置壁纸:', this.quotes[this.currentQuoteIndex]);
      
      // 等待画布就绪（必要时回退到屏幕尺寸）
      const ready = await this.ensureCanvasReady(1500);
      if (!ready) {
        promptAction.showToast({
          message: '壁纸预览未准备就绪，请稍后重试',
          duration: 2000
        });
        return;
      }
      
      promptAction.showToast({
        message: '正在生成壁纸...',
        duration: 2000
      });
      

      this.drawLayeredWaves(this.currentQuoteColor);
      
      // 等待绘制完成
      await new Promise<void>((resolve) => setTimeout(resolve, 500));
      
      // 将Canvas内容转换为ImageData
      const ctx = this.canvasElement; // 通过局部常量收窄类型，避免空指针
      if (!ctx) {
        console.error('Canvas上下文未就绪，无法导出图像数据');
        promptAction.showToast({
          message: '生成壁纸失败，请稍后重试',
          duration: 2000
        });
        return; // 安全返回，避免空引用
      }
      const imageData = ctx.getImageData(0, 0, this.canvasWidth, this.canvasHeight);
      
      // 创建PixelMap
      const pixelMap = await this.createPixelMapFromImageData(imageData);
      
      // 设置为系统壁纸
      await wallpaper.setWallpaper(pixelMap, wallpaper.WallpaperType.WALLPAPER_SYSTEM);
      
      console.log('壁纸设置成功');
      promptAction.showToast({
        message: '壁纸设置成功！',
        duration: 2000
      });
      
    } catch (err) {
       console.error('设置壁纸失败:', err);
       promptAction.showToast({
         message: '壁纸设置失败，请重试',
         duration: 2000
       });
     }
  }
  /**
   * 等待Canvas就绪，确保已获取上下文且尺寸有效；如尺寸无效则回退为屏幕分辨率
   * @param timeoutMs 最大等待时长
   * @returns 是否就绪
   */
  private async ensureCanvasReady(timeoutMs: number = 1000): Promise<boolean> {
    const start = Date.now();
    // 若还未初始化上下文，尝试从 this.canvasContext 获取
    if (!this.canvasElement && this.canvasContext) {
      this.canvasElement = this.canvasContext as CanvasRenderingContext2D;
    }
    while ((!this.canvasElement || this.canvasWidth === 0 || this.canvasHeight === 0) && Date.now() - start < timeoutMs) {
      await new Promise<void>((resolve) => setTimeout(resolve, 50));
    }
    // 若尺寸仍为0，使用屏幕尺寸作为回退，避免“未就绪”
    if ((this.canvasWidth === 0 || this.canvasHeight === 0) && this.canvasElement) {
      try {
        const d = await display.getDefaultDisplay();
        this.canvasWidth = d.width;
        this.canvasHeight = d.height;
      } catch (e) {
        console.warn('获取屏幕尺寸失败，保持原尺寸。');
      }
    }
    return !!this.canvasElement && this.canvasWidth > 0 && this.canvasHeight > 0;
  }

  /**
   * 将ImageData转换为PixelMap
   */
  private async createPixelMapFromImageData(imageData: ImageData): Promise<image.PixelMap> {
    try {
      // 创建PixelMap的配置
      const opts: image.InitializationOptions = {
        alphaType: 0, // UNKNOWN
        editable: true,
        pixelFormat: 3, // RGBA_8888
        scaleMode: 1, // CENTER_CROP
        size: {
          height: this.canvasHeight,
          width: this.canvasWidth
        }
      };
      
      // 从ImageData创建PixelMap
      const pixelMap = await image.createPixelMap(imageData.data.buffer as ArrayBuffer, opts);
      return pixelMap;
      
    } catch (err) {
      console.error('创建PixelMap失败:', err);
      throw new Error('创建PixelMap失败');
    }
  }
  /**
   * 编辑语录
   * 修复：确保传递序列化后的 JSON 字符串给 EditPage，与 Index.ets 和 EditPage.ets 的实现保持一致
   */
  private editQuote() {
    const quote = this.quotes[this.currentQuoteIndex];
    console.log('WallpaperPage: 尝试编辑语录:', quote); // 调试日志
    if (quote) { // 确保语录对象存在
      let quoteParam: string = '';
      try {
        // 关键修改：序列化语录对象为 JSON 字符串
        quoteParam = JSON.stringify(quote);
        console.log('WallpaperPage: 序列化后的语录参数:', quoteParam); // 调试日志
      } catch (serializeError) {
        console.error('WallpaperPage: 序列化语录对象失败:', serializeError, quote);
        promptAction.showToast({
          message: '数据准备失败，无法编辑'
        });
        return; // 终止执行
      }
      // 执行页面跳转
      router.pushUrl({
        url: 'pages/EditPage',
        params: {
          mode: 'edit',
          // 关键修改：传递序列化后的字符串
          quote: quoteParam
        }
      }).then(() => {
        console.log('WallpaperPage: 成功跳转到编辑页面');
      }).catch((error: Error) => {
        console.error('WallpaperPage: 跳转编辑页面失败:', error);
        promptAction.showToast({
          message: '跳转失败，请重试'
        });
      });
    } else {
      console.warn('WallpaperPage: 尝试编辑语录，但当前语录为空');
      promptAction.showToast({
        message: '无法编辑当前语录'
      });
    }
  }
  /**
   * 分享壁纸
   */
  private shareWallpaper() {
    // 确保Canvas已经绘制完成
    if (this.canvasElement && this.canvasWidth > 0 && this.canvasHeight > 0) {
      // 重新绘制确保最新状态
      this.drawLayeredWaves(this.currentQuoteColor);
    }
    this.isShareVisible = true;
    this.shareState = 'confirm';
  }
  /**
   * 关闭分享遮罩
   */
  private closeShareOverlay() {
    this.isShareVisible = false;
    this.shareState = 'confirm';
  }
  /**
   * 确认分享
   */
  private confirmShare() {
    this.shareState = 'loading';
    // 模拟生成过程
    setTimeout(() => {
      this.shareState = 'success';
    }, 2000);
  }
  /**
   * 调用系统分享
   */
  private callSystemShare() {
    console.log('调用系统分享面板');
    promptAction.showToast({
      message: '调用系统分享面板',
      duration: 2000
    });
    this.closeShareOverlay();
  }
  /**
   * 构建页面UI
   */
  build() {
    Stack() {
      // 主预览容器
      Stack() {
        // Canvas背景
        Canvas(this.canvasContext)
          .width('100%')
          .height('100%')
          .onReady(() => {
            console.log('Canvas onReady called');
            // 在onReady中获取Canvas上下文（与EditPage一致的用法）
            if (this.canvasContext) {
              this.canvasElement = this.canvasContext as CanvasRenderingContext2D;
            } else {
              console.error('Canvas上下文为空，无法初始化绘制');
              this.canvasElement = null;
            }
            console.log('Canvas context initialized:', !!this.canvasElement);
            // 立即尝试绘制初始背景
            if (this.canvasElement && this.canvasWidth > 0 && this.canvasHeight > 0) {
              setTimeout(() => {
                this.drawLayeredWaves(this.currentQuoteColor);
              }, 200);
            }
          })
          .onAreaChange((oldValue: Area, newValue: Area) => {
            // 关键修改：当Canvas尺寸改变时更新 @State 尺寸，这会触发 UI 更新和可能的副作用
            const newWidth = Number(newValue.width);
            const newHeight = Number(newValue.height);
            console.log(`Canvas尺寸变化: ${this.canvasWidth}x${this.canvasHeight} -> ${newWidth}x${newHeight}`);
            this.canvasWidth = newWidth;
            this.canvasHeight = newHeight;
            // 关键修改：尺寸更新后，立即尝试重绘
            if (this.canvasElement && this.canvasWidth > 0 && this.canvasHeight > 0) {
              setTimeout(() => {
                console.log('Canvas尺寸已更新，开始绘制波浪背景，使用颜色:', this.currentQuoteColor);
                this.drawLayeredWaves(this.currentQuoteColor); // 使用动态颜色
              }, 100); // 增加延迟确保Canvas完全初始化
            }
          })
        // 语录内容区域
        if (!this.isLoading && this.quotes.length > 0) {
          Column() {
            Text(this.quotes[this.currentQuoteIndex]?.text || '')
              .fontSize(this.getTextStyle(this.quotes[this.currentQuoteIndex]?.text || '').fontSize)
              .fontColor('#FFFFFF')
              .textAlign(TextAlign.Center)
              .lineHeight(this.getTextStyle(this.quotes[this.currentQuoteIndex]?.text || '').lineHeight)
              .fontWeight(FontWeight.Medium)
              .padding({ left: 40, right: 40, top: 20, bottom: 20 })
              .shadow({
                radius: 12,
                color: 'rgba(0, 0, 0, 0.6)',
                offsetX: 0,
                offsetY: 3
              })
              .maxLines(8) // 限制最大行数
              .textOverflow({ overflow: TextOverflow.Ellipsis }) // 文字溢出处理
              .wordBreak(WordBreak.BREAK_ALL) // 允许单词内换行
          }
          .width('90%') // 减少宽度留出更多边距
          .height('35%') // 限制高度避免重叠
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .position({ x: '5%', y: '32%' }) // 居中显示，避免与底部按钮重叠
          .backgroundColor('rgba(0, 0, 0, 0.1)') // 添加半透明背景提高可读性
          .borderRadius(16) // 圆角背景
        }
        // 返回按钮
        Button() {
          Text('←')
            .fontSize(24)
            .fontColor('#FFFFFF')
        }
        .width(40)
        .height(40)
        .backgroundColor('rgba(0, 0, 0, 0.3)')
        .borderRadius(20)
        .position({ x: 16, y: 48 })
        .onClick(() => this.goBack())
        // 导航提示
        if (this.quotes.length > 1) {
          Row() {
            ForEach(this.quotes, (quote: Quote, index: number) => {
              Circle()
                .width(8)
                .height(8)
                .fill(index === this.currentQuoteIndex ? '#FFFFFF' : 'rgba(255, 255, 255, 0.4)')
                .margin({ left: 4, right: 4 })
            })
          }
          .position({ x: '50%', y: '85%' })
          .translate({ x: '-50%', y: 0 })
        }
        // 底部操作栏
        if (this.isControlsVisible) {
          Row() {
            // 设置壁纸按钮
            Button() {
              Column() {
                Image($r('app.media.ic_wallpaper'))
                  .width(24)
                  .height(24)
                  .fillColor('#ffffff')
                Text('设置壁纸')
                  .fontSize(12)
                  .fontColor('#FFFFFF')
                  .margin({ top: 4 })
              }
            }
            .width(72)
            .height(72)
            .backgroundColor('rgba(255, 255, 255, 0.2)')
            .borderRadius(36)
            .padding(12)
            .onClick(() => this.setWallpaper())
            Blank()
            // 编辑按钮
            Button() {
              Column() {
                Image($r('app.media.ic_edit'))
                  .width(24)
                  .height(24)
                  .fillColor('#ffffff')
                Text('编辑语录')
                  .fontSize(12)
                  .fontColor('#ffffff')
                  .margin({ top: 4 })
              }
            }
            .width(72)
            .height(72)
            .backgroundColor('#4A90E2')
            .borderRadius(36)
            .padding(12)
            .onClick(() => this.editQuote())
            Blank()
            // 分享按钮
            Button() {
              Column() {
                Image($r('app.media.ic_share'))
                  .width(24)
                  .height(24)
                  .fillColor('#ffffff')
                Text('分享壁纸')
                  .fontSize(12)
                  .fontColor('#FFFFFF')
                  .margin({ top: 4 })
              }
            }
            .width(72)
            .height(72)
            .backgroundColor('rgba(255, 255, 255, 0.2)')
            .borderRadius(36)
            .padding(12)
            .onClick(() => this.shareWallpaper())
          }
          .width('100%')
          .padding({ left: 24, right: 24, bottom: 32 })
          .position({ x: 0, y: '100%' })
          .translate({ x: 0, y: '-100%' })
        }
        // 分享生成遮罩
        if (this.isShareVisible) {
          Column() {
            // 遮罩背景
            Column()
              .width('100%')
              .height('100%')
              .backgroundColor('rgba(0, 0, 0, 0.5)')
              .onClick(() => this.closeShareOverlay())
            // 分享内容卡片
            Column() {
              Text('分享壁纸')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#333333')
                .margin({ bottom: 16 })
              // 预览内容
              Column() {
                Text(this.quotes[this.currentQuoteIndex]?.text || '')
                  .fontSize(16)
                  .fontColor('#333333')
                  .textAlign(TextAlign.Center)
                  .lineHeight(24)
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#F8F9FA')
              .borderRadius(8)
              .margin({ bottom: 20 })
              // 状态显示
              if (this.shareState === 'loading') {
                Column() {
                  LoadingProgress()
                    .width(32)
                    .height(32)
                    .color('#007AFF')
                  Text('正在生成分享图片...')
                    .fontSize(14)
                    .fontColor('#666666')
                    .margin({ top: 8 })
                }
                .margin({ bottom: 20 })
              } else if (this.shareState === 'success') {
                Column() {
                  Text('✅')
                    .fontSize(32)
                  Text('生成成功！')
                    .fontSize(14)
                    .fontColor('#666666')
                    .margin({ top: 8 })
                }
                .margin({ bottom: 20 })
              }
              // 操作按钮
              Row() {
                Button('取消')
                  .width(80)
                  .height(40)
                  .fontSize(16)
                  .fontColor('#666666')
                  .backgroundColor('#F5F5F5')
                  .borderRadius(8)
                  .onClick(() => this.closeShareOverlay())
                Blank()
                Button(this.shareState === 'loading' ? '生成中...' :
                  this.shareState === 'success' ? '调用分享' : '分享')
                  .width(120)
                  .height(40)
                  .fontSize(16)
                  .fontColor('#FFFFFF')
                  .backgroundColor(this.shareState === 'loading' ? '#CCCCCC' : '#007AFF')
                  .borderRadius(8)
                  .enabled(this.shareState !== 'loading')
                  .onClick(() => {
                    if (this.shareState === 'success') {
                      this.callSystemShare();
                    } else {
                      this.confirmShare();
                    }
                  })
              }
              .width('100%')
            }
            .width('80%')
            .padding(24)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
            .position({ x: '50%', y: '50%' })
            .translate({ x: '-50%', y: '-50%' })
          }
          .width('100%')
          .height('100%')
          .position({ x: 0, y: 0 })
        }
        // 加载状态
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(48)
              .height(48)
              .color('#FFFFFF')
            Text('加载中...')
              .fontSize(16)
              .fontColor('#FFFFFF')
              .margin({ top: 16 })
          }
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0, 0, 0, 0.8)')
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .gesture(
        // 添加触摸手势
        PanGesture()
          .onActionStart((event) => {
            this.touchStartX = event.fingerList[0].globalX;
            this.touchStartY = event.fingerList[0].globalY;
          })
          .onActionEnd((event) => {
            const touchEndX = event.fingerList[0].globalX;
            const touchEndY = event.fingerList[0].globalY;
            const deltaX = touchEndX - this.touchStartX;
            const deltaY = touchEndY - this.touchStartY;
            // 判断是否为水平滑动
            if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 50) {
              if (deltaX > 0) {
                // 向右滑动 - 上一条
                this.previousQuote();
              } else {
                // 向左滑动 - 下一条
                this.nextQuote();
              }
            }
          })
      )
      .onClick(() => {
        this.toggleControls();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000000') // 保持黑色背景
  }
}