import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { bundleManager } from '@kit.AbilityKit';

/**
 * 字体大小选项接口
 */
interface FontSizeOption {
  label: string;
  value: number;
}

/**
 * 对话框按钮接口
 */
interface DialogButton {
  text: string;
  color: string;
}

/**
 * Toast选项接口
 */
interface ShowToastOptions {
  message: string;
  duration?: number;
}

/**
 * 设置页面
 * 基于settings.html实现应用设置功能
 * 包含主题设置、字体设置、数据管理、关于应用等功能
 */
@Entry
@Component
struct SettingsPage {
  // 设置项状态
  @State isDarkMode: boolean = false;
  @State fontSize: number = 16;
  @State autoBackup: boolean = true;
  @State notificationEnabled: boolean = true;
  @State cacheSize: string = '0 MB';
  @State appVersion: string = '1.0.0';
  
  // 页面状态
  @State isLoading: boolean = false;
  
  // 设置选项
  private fontSizeOptions: FontSizeOption[] = [
    { label: '小', value: 14 },
    { label: '中', value: 16 },
    { label: '大', value: 18 },
    { label: '特大', value: 20 }
  ];

  /**
   * 页面初始化
   */
  async aboutToAppear() {
    await this.loadSettings();
    await this.loadAppInfo();
  }

  /**
   * 加载设置信息
   */
  async loadSettings() {
    try {
      const dataPreferences = await preferences.getPreferences(getContext(), 'app_settings');
      
      this.isDarkMode = await dataPreferences.get('dark_mode', false) as boolean;
      this.fontSize = await dataPreferences.get('font_size', 16) as number;
      this.autoBackup = await dataPreferences.get('auto_backup', true) as boolean;
      this.notificationEnabled = await dataPreferences.get('notification_enabled', true) as boolean;
      
      // 计算缓存大小
      await this.calculateCacheSize();
    } catch (error) {
      console.error('加载设置失败:', error);
    }
  }

  /**
   * 加载应用信息
   */
  async loadAppInfo() {
    try {
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
      this.appVersion = bundleInfo.versionName || '1.0.0';
    } catch (error) {
      console.error('获取应用信息失败:', error);
    }
  }

  /**
   * 计算缓存大小
   */
  async calculateCacheSize() {
    try {
      // TODO: 实现缓存大小计算
      this.cacheSize = '2.5 MB';
    } catch (error) {
      console.error('计算缓存大小失败:', error);
      this.cacheSize = '未知';
    }
  }

  /**
   * 保存设置
   */
  async saveSetting(key: string, value: string | number | boolean) {
    try {
      const dataPreferences = await preferences.getPreferences(getContext(), 'app_settings');
      await dataPreferences.put(key, value);
      await dataPreferences.flush();
    } catch (error) {
      console.error('保存设置失败:', error);
      const saveErrorToast: ShowToastOptions = {
        message: '保存设置失败',
        duration: 2000
      };
      promptAction.showToast(saveErrorToast);
    }
  }

  /**
   * 切换深色模式
   */
  async toggleDarkMode(enabled: boolean) {
    this.isDarkMode = enabled;
    await this.saveSetting('dark_mode', enabled);
    
    promptAction.showToast({
      message: enabled ? '已开启深色模式' : '已关闭深色模式',
      duration: 2000
    });
  }

  /**
   * 设置字体大小
   */
  async setFontSize(size: number) {
    this.fontSize = size;
    await this.saveSetting('font_size', size);
    
    promptAction.showToast({
      message: `字体大小已设置为${size}px`,
      duration: 2000
    });
  }

  /**
   * 切换自动备份
   */
  async toggleAutoBackup(enabled: boolean) {
    this.autoBackup = enabled;
    await this.saveSetting('auto_backup', enabled);
    
    const backupToast: ShowToastOptions = {
      message: enabled ? '已开启自动备份' : '已关闭自动备份',
      duration: 2000
    };
    promptAction.showToast(backupToast);
  }

  /**
   * 切换通知
   */
  async toggleNotification(enabled: boolean) {
    this.notificationEnabled = enabled;
    await this.saveSetting('notification_enabled', enabled);
    
    const notificationToast: ShowToastOptions = {
      message: enabled ? '已开启通知' : '已关闭通知',
      duration: 2000
    };
    promptAction.showToast(notificationToast);
  }

  /**
   * 清除缓存
   */
  async clearCache() {
    promptAction.showDialog({
      title: '清除缓存',
      message: '确定要清除应用缓存吗？这将删除临时文件和图片缓存。',
      buttons: [
        {
          text: '取消',
          color: '#666666'
        },
        {
          text: '清除',
          color: '#FF3B30'
        }
      ] as DialogButton[]
    }).then(async (result) => {
      if (result.index === 1) {
        this.isLoading = true;
        try {
          // TODO: 实现缓存清除逻辑
          await new Promise<void>(resolve => setTimeout(resolve, 1000)); // 模拟清除过程
          
          this.cacheSize = '0 MB';
          const clearSuccessToast: ShowToastOptions = {
            message: '缓存已清除',
            duration: 2000
          };
          promptAction.showToast(clearSuccessToast);
        } catch (error) {
          console.error('清除缓存失败:', error);
          const clearErrorToast: ShowToastOptions = {
            message: '清除缓存失败',
            duration: 2000
          };
          promptAction.showToast(clearErrorToast);
        } finally {
          this.isLoading = false;
        }
      }
    });
  }

  /**
   * 检查更新
   */
  async checkUpdate() {
    this.isLoading = true;
    try {
      // TODO: 实现更新检查逻辑
      await new Promise<void>(resolve => setTimeout(resolve, 2000)); // 模拟检查过程
      
      promptAction.showDialog({
        title: '检查更新',
        message: '当前已是最新版本',
        buttons: [{ text: '知道了', color: '#007AFF' }] as DialogButton[]
      });
    } catch (error) {
      console.error('检查更新失败:', error);
      const updateErrorToast: ShowToastOptions = {
        message: '检查更新失败',
        duration: 2000
      };
      promptAction.showToast(updateErrorToast);
    } finally {
      this.isLoading = false;
    }
  }

  /**
   * 显示关于信息
   */
  showAbout() {
    promptAction.showDialog({
      title: '关于语录壁纸',
      message: `版本：${this.appVersion}\n\n语录壁纸是一款简洁优雅的语录管理和壁纸生成应用。\n\n• 收集和管理您喜爱的语录\n• 生成精美的语录壁纸\n• 支持数据导入导出\n• 多种个性化设置\n\n感谢您的使用！`,
      buttons: [{ text: '知道了', color: '#007AFF' }] as DialogButton[]
    });
  }

  /**
   * 显示隐私政策
   */
  showPrivacyPolicy() {
    promptAction.showDialog({
      title: '隐私政策',
      message: '我们重视您的隐私保护：\n\n• 所有数据仅存储在本地设备\n• 不会收集或上传个人信息\n• 不会访问您的其他应用数据\n• 导出功能仅在您主动操作时执行\n\n如有疑问，请联系开发者。',
      buttons: [{ text: '知道了', color: '#007AFF' }] as DialogButton[]
    });
  }

  /**
   * 返回上一页
   */
  goBack() {
    router.back();
  }

  /**
   * 构建页面UI
   */
  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button() {
          Text('←')
            .fontSize(20)
            .fontColor('#333333')
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => this.goBack())
        
        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        
        // 占位符保持居中
        Text('')
          .width(40)
      }
      .width('100%')
      .height(56)
      .padding({ left: 16, right: 16 })
      .backgroundColor('#FFFFFF')
      .border({ width: { bottom: 1 }, color: '#E5E5E5' })

      Scroll() {
        Column() {
          // 外观设置
          Column() {
            Text('外观设置')
              .fontSize(14)
              .fontColor('#666666')
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 12 })

            // 深色模式
            Row() {
              Row() {
                Text('🌙')
                  .fontSize(20)
                  .margin({ right: 12 })
                
                Column() {
                  Text('深色模式')
                    .fontSize(16)
                    .fontColor('#333333')
                  
                  Text('开启后界面将使用深色主题')
                    .fontSize(12)
                    .fontColor('#666666')
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
              }
              .layoutWeight(1)
              
              Toggle({ type: ToggleType.Switch, isOn: this.isDarkMode })
                .onChange((isOn: boolean) => {
                  this.toggleDarkMode(isOn);
                })
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            .border({ width: { bottom: 1 }, color: '#F0F0F0' })

            // 字体大小
            Row() {
              Row() {
                Text('🔤')
                  .fontSize(20)
                  .margin({ right: 12 })
                
                Column() {
                  Text('字体大小')
                    .fontSize(16)
                    .fontColor('#333333')
                  
                  Text(`当前：${this.fontSize}px`)
                    .fontSize(12)
                    .fontColor('#666666')
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
              }
              .layoutWeight(1)
              
              Text('>')
                .fontSize(16)
                .fontColor('#CCCCCC')
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            .onClick(() => {
              // 使用简单的循环切换字体大小
              const currentIndex = this.fontSizeOptions.findIndex(option => option.value === this.fontSize);
              const nextIndex = (currentIndex + 1) % this.fontSizeOptions.length;
              this.setFontSize(this.fontSizeOptions[nextIndex].value);
            })
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ bottom: 16 })

          // 功能设置
          Column() {
            Text('功能设置')
              .fontSize(14)
              .fontColor('#666666')
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 12 })

            // 自动备份
            Row() {
              Row() {
                Text('💾')
                  .fontSize(20)
                  .margin({ right: 12 })
                
                Column() {
                  Text('自动备份')
                    .fontSize(16)
                    .fontColor('#333333')
                  
                  Text('定期自动备份语录数据')
                    .fontSize(12)
                    .fontColor('#666666')
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
              }
              .layoutWeight(1)
              
              Toggle({ type: ToggleType.Switch, isOn: this.autoBackup })
                .onChange((isOn: boolean) => {
                  this.toggleAutoBackup(isOn);
                })
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            .border({ width: { bottom: 1 }, color: '#F0F0F0' })

            // 通知设置
            Row() {
              Row() {
                Text('🔔')
                  .fontSize(20)
                  .margin({ right: 12 })
                
                Column() {
                  Text('推送通知')
                    .fontSize(16)
                    .fontColor('#333333')
                  
                  Text('接收应用相关通知')
                    .fontSize(12)
                    .fontColor('#666666')
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
              }
              .layoutWeight(1)
              
              Toggle({ type: ToggleType.Switch, isOn: this.notificationEnabled })
                .onChange((isOn: boolean) => {
                  this.toggleNotification(isOn);
                })
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ bottom: 16 })

          // 存储管理
          Column() {
            Text('存储管理')
              .fontSize(14)
              .fontColor('#666666')
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 12 })

            // 缓存大小
            Row() {
              Row() {
                Text('📁')
                  .fontSize(20)
                  .margin({ right: 12 })
                
                Column() {
                  Text('缓存大小')
                    .fontSize(16)
                    .fontColor('#333333')
                  
                  Text(this.cacheSize)
                    .fontSize(12)
                    .fontColor('#666666')
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
              }
              .layoutWeight(1)
              
              Button('清除')
                .height(32)
                .fontSize(14)
                .fontColor('#FF3B30')
                .backgroundColor('#FFF0F0')
                .borderRadius(6)
                .enabled(!this.isLoading)
                .onClick(() => this.clearCache())
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ bottom: 16 })

          // 关于应用
          Column() {
            Text('关于应用')
              .fontSize(14)
              .fontColor('#666666')
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 12 })

            // 版本信息
            Row() {
              Row() {
                Text('ℹ️')
                  .fontSize(20)
                  .margin({ right: 12 })
                
                Column() {
                  Text('版本信息')
                    .fontSize(16)
                    .fontColor('#333333')
                  
                  Text(`v${this.appVersion}`)
                    .fontSize(12)
                    .fontColor('#666666')
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
              }
              .layoutWeight(1)
              
              Text('>')
                .fontSize(16)
                .fontColor('#CCCCCC')
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            .border({ width: { bottom: 1 }, color: '#F0F0F0' })
            .onClick(() => this.showAbout())

            // 检查更新
            Row() {
              Row() {
                Text('🔄')
                  .fontSize(20)
                  .margin({ right: 12 })
                
                Text('检查更新')
                  .fontSize(16)
                  .fontColor('#333333')
              }
              .layoutWeight(1)
              
              if (this.isLoading) {
                LoadingProgress()
                  .width(20)
                  .height(20)
                  .color('#007AFF')
              } else {
                Text('>')
                  .fontSize(16)
                  .fontColor('#CCCCCC')
              }
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            .border({ width: { bottom: 1 }, color: '#F0F0F0' })
            .onClick(() => {
              if (!this.isLoading) {
                this.checkUpdate();
              }
            })

            // 隐私政策
            Row() {
              Row() {
                Text('🔒')
                  .fontSize(20)
                  .margin({ right: 12 })
                
                Text('隐私政策')
                  .fontSize(16)
                  .fontColor('#333333')
              }
              .layoutWeight(1)
              
              Text('>')
                .fontSize(16)
                .fontColor('#CCCCCC')
            }
            .width('100%')
            .padding({ top: 16, bottom: 16 })
            .onClick(() => this.showPrivacyPolicy())
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ bottom: 32 })
        }
        .padding(16)
      }
      .layoutWeight(1)
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}