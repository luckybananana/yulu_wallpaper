import { drawing } from '@kit.ArkGraphics2D';
import { image } from '@kit.ImageKit';
import { font } from '@kit.ArkUI';
import { Context } from '@kit.AbilityKit';
import { Quote } from './QuoteDataManager';

// 壁纸配置接口
export interface WallpaperConfig {
  width: number;
  height: number;
  fontSize: number;
  lineHeight: number;
  textColor: string;
  backgroundColor: string;
  gradientColors: string[];
  fontFamily: string;
  padding: number;
  maxWidth: number;
  waveCount: number;
  waveAmplitude: number;
  waveFrequency: number;
}

// 预设主题配置接口
interface PresetThemes {
  '深蓝夜空': Partial<WallpaperConfig>;
  '温暖日落': Partial<WallpaperConfig>;
  '清新绿意': Partial<WallpaperConfig>;
  '优雅紫调': Partial<WallpaperConfig>;
  '简约黑白': Partial<WallpaperConfig>;
}

// RGBA颜色接口
interface RgbaColor {
  r: number;
  g: number;
  b: number;
  a: number;
}

// 默认配置
const DEFAULT_CONFIG: WallpaperConfig = {
  width: 1080,
  height: 1920,
  fontSize: 48,
  lineHeight: 1.6,
  textColor: '#FFFFFF',
  backgroundColor: '#1a1a2e',
  gradientColors: ['#1a1a2e', '#16213e', '#0f3460'],
  fontFamily: 'fangzheng',
  padding: 80,
  maxWidth: 920,
  waveCount: 3,
  waveAmplitude: 50,
  waveFrequency: 0.02
};

// 波浪层配置
interface WaveLayer {
  color: string;
  opacity: number;
  amplitude: number;
  frequency: number;
  phase: number;
  yOffset: number;
}

// 壁纸生成器类
export class WallpaperGenerator {
  private static instance: WallpaperGenerator;
  private context: Context;
  private isFontRegistered: boolean = false;

  constructor(context: Context) {
    this.context = context;
  }

  // 获取单例实例
  public static getInstance(context?: Context): WallpaperGenerator {
    if (!WallpaperGenerator.instance && context) {
      WallpaperGenerator.instance = new WallpaperGenerator(context);
    }
    return WallpaperGenerator.instance;
  }

  // 注册自定义字体
  private async registerFont(): Promise<void> {
    if (this.isFontRegistered) {
      return;
    }

    try {
      await font.registerFont({
        familyName: 'fangzheng',
        familySrc: '$rawfile("fangzheng.ttf")'
      });
      this.isFontRegistered = true;
    } catch (error) {
      console.error('注册字体失败:', error);
    }
  }

  // 生成壁纸（简化版本）
  public async generateWallpaper(
    quote: Quote,
    config: Partial<WallpaperConfig> = {}
  ): Promise<image.PixelMap> {
    await this.registerFont();
    
    const finalConfig: WallpaperConfig = {
      width: config.width ?? DEFAULT_CONFIG.width,
      height: config.height ?? DEFAULT_CONFIG.height,
      backgroundColor: config.backgroundColor ?? DEFAULT_CONFIG.backgroundColor,
      textColor: config.textColor ?? DEFAULT_CONFIG.textColor,
      fontSize: config.fontSize ?? DEFAULT_CONFIG.fontSize,
      fontFamily: config.fontFamily ?? DEFAULT_CONFIG.fontFamily,
      gradientColors: config.gradientColors ?? DEFAULT_CONFIG.gradientColors,
      waveCount: config.waveCount ?? DEFAULT_CONFIG.waveCount,
      waveAmplitude: config.waveAmplitude ?? DEFAULT_CONFIG.waveAmplitude,
      waveFrequency: config.waveFrequency ?? DEFAULT_CONFIG.waveFrequency,
      lineHeight: config.lineHeight ?? DEFAULT_CONFIG.lineHeight,
      padding: config.padding ?? DEFAULT_CONFIG.padding,
      maxWidth: config.maxWidth ?? DEFAULT_CONFIG.maxWidth
    };
    
    // 创建简单的纯色背景PixelMap
    return this.createSimpleWallpaper(quote, finalConfig);
  }

  // 注意：原有的复杂绘制方法已简化，使用createSimpleWallpaper替代

  // 原有的波浪层绘制方法已移除，使用简化版本

  // 原有的复杂绘制方法已移除，使用简化版本

  // 创建简单壁纸
  private async createSimpleWallpaper(quote: Quote, config: WallpaperConfig): Promise<image.PixelMap> {
    const width = config.width;
    const height = config.height;
    const buffer = new ArrayBuffer(width * height * 4); // RGBA
    const view = new Uint8Array(buffer);
    
    // 解析背景颜色
    const bgColor = this.hexToRgba(config.backgroundColor);
    
    // 填充背景色
    for (let i = 0; i < width * height; i++) {
      const offset = i * 4;
      view[offset] = bgColor.r;     // R
      view[offset + 1] = bgColor.g; // G
      view[offset + 2] = bgColor.b; // B
      view[offset + 3] = bgColor.a; // A
    }
    
    const imageInfo: image.ImageInfo = {
      size: { height: height, width: width },
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      alphaType: image.AlphaType.OPAQUE,
      density: 160,
      stride: width * 4,
      mimeType: 'image/png',
      isHdr: false
    };
    
    return await image.createPixelMap(buffer, imageInfo);
  }
  
  // 十六进制颜色转换为RGBA对象
  private hexToRgba(hex: string): RgbaColor {
    const r = parseInt(hex.slice(1, 3), 16);
    const g = parseInt(hex.slice(3, 5), 16);
    const b = parseInt(hex.slice(5, 7), 16);
    return { r, g, b, a: 255 };
  }

  // 生成预设主题配置
  public static getPresetThemes(): PresetThemes {
    const themes: PresetThemes = {
      '深蓝夜空': {
        backgroundColor: '#1a1a2e',
        gradientColors: ['#1a1a2e', '#16213e', '#0f3460'],
        textColor: '#FFFFFF'
      } as Partial<WallpaperConfig>,
      '温暖日落': {
        backgroundColor: '#ff6b6b',
        gradientColors: ['#ff6b6b', '#ffa500', '#ff4757'],
        textColor: '#FFFFFF'
      } as Partial<WallpaperConfig>,
      '清新绿意': {
        backgroundColor: '#2ed573',
        gradientColors: ['#2ed573', '#1dd1a1', '#00d2d3'],
        textColor: '#FFFFFF'
      } as Partial<WallpaperConfig>,
      '优雅紫调': {
        backgroundColor: '#5f27cd',
        gradientColors: ['#5f27cd', '#341f97', '#8c7ae6'],
        textColor: '#FFFFFF'
      } as Partial<WallpaperConfig>,
      '简约黑白': {
        backgroundColor: '#2f3542',
        gradientColors: ['#2f3542', '#57606f', '#747d8c'],
        textColor: '#FFFFFF'
      } as Partial<WallpaperConfig>
    };
    return themes;
  }
}