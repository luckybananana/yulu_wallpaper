import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { QuoteDataManager, Quote } from '../common/QuoteDataManager';

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

/**
 * 壁纸预览页面
 * 基于wallpaper.html实现壁纸预览、Canvas绘制分层波浪背景、触摸滑动切换语录等功能
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
  private canvasWidth: number = 0;
  private canvasHeight: number = 0;
  
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
      
      // 数据加载完成后重绘Canvas
      setTimeout(() => {
        if (this.canvasContext) {
          this.drawLayeredWaves('#4A90E2');
        }
      }, 200);
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
      
      // 数据加载完成后重绘Canvas
      setTimeout(() => {
        if (this.canvasContext) {
          this.drawLayeredWaves('#4A90E2');
        }
      }, 200);
    }
  }

  /**
   * 初始化索引
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
   */
  private drawLayeredWaves(baseColor: string) {
    if (!this.canvasContext || this.canvasWidth === 0 || this.canvasHeight === 0) return;
    
    const ctx = this.canvasContext;
    const width = this.canvasWidth;
    const height = this.canvasHeight;
    const baseRgb = this.hexToRgb(baseColor);
    
    // 清空画布
    ctx.clearRect(0, 0, width, height);
    
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
      const style: TextStyle = { fontSize: 28, lineHeight: 1.4 };
      return style;
    } else if (length <= 30) {
      const style: TextStyle = { fontSize: 24, lineHeight: 1.5 };
      return style;
    } else if (length <= 50) {
      const style: TextStyle = { fontSize: 20, lineHeight: 1.6 };
      return style;
    } else {
      const style: TextStyle = { fontSize: 18, lineHeight: 1.7 };
      return style;
    }
  }

  /**
   * 切换到指定语录
   */
  private switchToQuote(index: number) {
    if (index < 0 || index >= this.quotes.length) return;
    
    this.currentQuoteIndex = index;
    // 重新绘制波浪背景
    setTimeout(() => {
      if (this.quotes[index]) {
        this.drawLayeredWaves('#4A90E2');
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
   * 设置壁纸
   */
  private setWallpaper() {
    console.log('设置壁纸:', this.quotes[this.currentQuoteIndex]);
    
    promptAction.showToast({
      message: '正在设置壁纸...',
      duration: 2000
    });
    
    setTimeout(() => {
      promptAction.showToast({
        message: '壁纸设置成功！',
        duration: 2000
      });
    }, 2000);
  }

  /**
   * 编辑语录
   */
  private editQuote() {
    const quote = this.quotes[this.currentQuoteIndex];
    router.pushUrl({
      url: 'pages/EditPage',
      params: {
        mode: 'edit',
        quote: quote
      }
    });
  }

  /**
   * 分享壁纸
   */
  private shareWallpaper() {
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
      Column() {
        // Canvas背景
        Canvas(this.canvasContext)
          .width('100%')
          .height('100%')
          .backgroundColor('#E6E6E6') // 与wallpaper.html保持一致
          .onReady(() => {
            // 获取Canvas尺寸
            this.canvasWidth = 360; // 根据实际容器宽度调整
            this.canvasHeight = 640; // 根据实际容器高度调整
            
            console.log('Canvas初始化完成，尺寸:', this.canvasWidth, 'x', this.canvasHeight);
            
            // 延迟绘制，确保数据已加载
            setTimeout(() => {
              if (this.canvasContext && !this.isLoading) {
                console.log('开始绘制波浪背景');
                this.drawLayeredWaves('#4A90E2');
              }
            }, 100);
          })
          .onAreaChange((oldValue: Area, newValue: Area) => {
            // 当Canvas尺寸改变时更新尺寸
            this.canvasWidth = Number(newValue.width);
            this.canvasHeight = Number(newValue.height);
            // 重新绘制
            if (this.canvasContext && !this.isLoading) {
              setTimeout(() => {
                this.drawLayeredWaves('#4A90E2');
              }, 50);
            }
          })
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

      // 语录内容区域
      if (!this.isLoading && this.quotes.length > 0) {
        Column() {
          Text(this.quotes[this.currentQuoteIndex]?.text || '')
            .fontSize(this.getTextStyle(this.quotes[this.currentQuoteIndex]?.text || '').fontSize)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .lineHeight(this.getTextStyle(this.quotes[this.currentQuoteIndex]?.text || '').lineHeight)
            .fontWeight(FontWeight.Medium)
            .padding({ left: 32, right: 32 })
            .shadow({
              radius: 8,
              color: 'rgba(0, 0, 0, 0.3)',
              offsetX: 0,
              offsetY: 2
            })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .position({ x: 0, y: '40%' })
      }

      // 返回按钮
      Button() {
        Text('←')
          .fontSize(24)
          .fontColor('#FFFFFF')
      }
      .width(48)
      .height(48)
      .backgroundColor('rgba(0, 0, 0, 0.3)')
      .borderRadius(24)
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
        .position({ x: '50%', y: '75%' })
        .translate({ x: '-50%', y: 0 })
      }

      // 底部操作栏
      if (this.isControlsVisible) {
        Row() {
          // 设置壁纸按钮
          Button() {
            Column() {
              Text('📱')
                .fontSize(20)
              Text('设置壁纸')
                .fontSize(12)
                .fontColor('#FFFFFF')
                .margin({ top: 4 })
            }
          }
          .backgroundColor('rgba(0, 0, 0, 0.6)')
          .borderRadius(12)
          .padding(12)
          .onClick(() => this.setWallpaper())

          Blank()

          // 编辑按钮
          Button() {
            Column() {
              Text('✏️')
                .fontSize(20)
              Text('编辑')
                .fontSize(12)
                .fontColor('#FFFFFF')
                .margin({ top: 4 })
            }
          }
          .backgroundColor('rgba(0, 0, 0, 0.6)')
          .borderRadius(12)
          .padding(12)
          .onClick(() => this.editQuote())

          Blank()

          // 分享按钮
          Button() {
            Column() {
              Text('📤')
                .fontSize(20)
              Text('分享')
                .fontSize(12)
                .fontColor('#FFFFFF')
                .margin({ top: 4 })
            }
          }
          .backgroundColor('rgba(0, 0, 0, 0.6)')
          .borderRadius(12)
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
                .maxLines(4)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
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
    .backgroundColor('#000000')
  }
}