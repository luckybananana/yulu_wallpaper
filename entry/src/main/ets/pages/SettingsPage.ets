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
 * 对话框选项接口 (添加这个接口来匹配 promptAction.showDialog 的参数)
 */
interface ShowDialogOptions {
  title: string;
  message: string;
  buttons: DialogButton[];
  // 可以根据需要添加其他属性，如 alignment, autoCancel 等
}

/**
 * 设置页面
 * 基于settings.html实现应用设置功能
 * 包含主题设置、字体设置、数据管理、关于应用等功能
 */
@Entry
@Component
struct SettingsPage {
  // 设置项状态 (保留 appVersion, isLoading)
  // @State autoBackup: boolean = true; // 已删除
  // @State notificationEnabled: boolean = true; // 已删除
  @State appVersion: string = '1.0.0';
  // 页面状态
  @State isLoading: boolean = false;

  /**
   * 页面初始化
   */
  async aboutToAppear() {
    // await this.loadSettings(); // 已删除对 loadSettings 的调用
    await this.loadAppInfo();
  }

  /**
   * 加载设置信息 (已删除此方法)
   */
  // async loadSettings() {
  //   try {
  //     const dataPreferences = await preferences.getPreferences(getContext(), 'app_settings');
  //     this.autoBackup = await dataPreferences.get('auto_backup', true) as boolean;
  //     this.notificationEnabled = await dataPreferences.get('notification_enabled', true) as boolean;
  //   } catch (error) {
  //     console.error('加载设置失败:', error);
  //   }
  // }

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
   * 保存设置 (保留方法，但可能仅用于其他设置)
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
   * 切换自动备份 (已删除此方法)
   */
  // async toggleAutoBackup(enabled: boolean) {
  //   this.autoBackup = enabled;
  //   await this.saveSetting('auto_backup', enabled);
  //   const backupToast: ShowToastOptions = {
  //     message: enabled ? '已开启自动备份' : '已关闭自动备份',
  //     duration: 2000
  //   };
  //   promptAction.showToast(backupToast);
  // }

  /**
   * 切换通知 (已删除此方法)
   */
  // async toggleNotification(enabled: boolean) {
  //   this.notificationEnabled = enabled;
  //   await this.saveSetting('notification_enabled', enabled);
  //   const notificationToast: ShowToastOptions = {
  //     message: enabled ? '已开启通知' : '已关闭通知',
  //     duration: 2000
  //   };
  //   promptAction.showToast(notificationToast);
  // }

  /**
   * 检查更新
   */
  async checkUpdate() {
    this.isLoading = true;
    try {
      // TODO: 实现更新检查逻辑
      await new Promise<void>(resolve => setTimeout(resolve, 2000)); // 模拟检查过程
      const dialogOptions: ShowDialogOptions = { // 使用接口类型
        title: '检查更新',
        message: '当前已是最新版本',
        buttons: [{ text: '知道了', color: '#007AFF' }]
      };
      promptAction.showDialog(dialogOptions); // 传递类型安全的对象
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
    const dialogOptions: ShowDialogOptions = { // 使用接口类型
      title: '关于语录壁纸',
      message: `版本：${this.appVersion}\n语录壁纸是一款简洁优雅的语录管理和壁纸生成应用。\n• 收集和管理您喜爱的语录\n• 生成精美的语录壁纸\n• 支持数据导入导出\n• 多种个性化设置\n感谢您的使用！`, // 修复换行符
      buttons: [{ text: '知道了', color: '#007AFF' }]
    };
    promptAction.showDialog(dialogOptions); // 传递类型安全的对象
  }

  /**
   * 显示隐私政策 (修复此方法)
   */
  showPrivacyPolicy() {
    // 修复 showDialog 调用
    const dialogOptions: ShowDialogOptions = { // 使用接口类型
      title: '隐私政策',
      message: '我们重视您的隐私保护：\n• 所有数据仅存储在本地设备\n• 不会收集或上传个人信息\n• 不会访问您的其他应用数据\n• 导出功能仅在您主动操作时执行\n如有疑问，请联系开发者。', // 修复字符串和换行符
      buttons: [{ text: '知道了', color: '#007AFF' }] // 修复 buttons 格式
    };
    promptAction.showDialog(dialogOptions); // 传递正确类型的对象
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
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor('#007AFF')
        }
        .backgroundColor(Color.Transparent)
        .onClick(() => this.goBack())
        Text('设置')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1D1D1F')
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
          // 功能设置 (已删除整个 Column 块)
          // 关于应用
          Column() {
            Row() {
              Image($r('app.media.ic_about'))
                .width(24)
                .height(24)
                .fillColor('#007AFF')
                .margin({ right: 8 })
              Text('关于应用')
                .fontSize(18)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1D1D1F')
            }
            .width('100%')
            .margin({ bottom: 20 })
            // 版本信息
            Row() {
              Row() {
                Image($r('app.media.ic_Version'))
                  .width(24)
                  .height(24)
                  .fillColor('#5856D6')
                  .margin({ right: 16 })
                Column() {
                  Text('版本信息')
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1D1D1F')
                  Text(`v${this.appVersion}`)
                    .fontSize(14)
                    .fontColor('#86868B')
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
              }
              .layoutWeight(1)
              Text('>')
                .fontSize(18)
                .fontColor('#C7C7CC')
            }
            .width('100%')
            .padding({ top: 20, bottom: 20 })
            .border({ width: { bottom: 1 }, color: '#F2F2F7' })
            .onClick(() => this.showAbout())
            // 检查更新
            Row() {
              Row() {
                Image($r('app.media.ic_information'))
                  .width(24)
                  .height(24)
                  .fillColor('#30D158')
                  .margin({ right: 16 })
                Text('检查更新')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1D1D1F')
              }
              .layoutWeight(1)
              if (this.isLoading) {
                LoadingProgress()
                  .width(24)
                  .height(24)
                  .color('#007AFF')
              } else {
                Text('>')
                  .fontSize(18)
                  .fontColor('#C7C7CC')
              }
            }
            .width('100%')
            .padding({ top: 20, bottom: 20 })
            .border({ width: { bottom: 1 }, color: '#F2F2F7' })
            .onClick(() => {
              if (!this.isLoading) {
                this.checkUpdate();
              }
            })
            // 隐私政策
            Row() {
              Row() {
                Image($r('app.media.ic_privacy'))
                  .width(24)
                  .height(24)
                  .fillColor('#FF3B30')
                  .margin({ right: 16 })
                Text('隐私政策')
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1D1D1F')
              }
              .layoutWeight(1)
              Text('>')
                .fontSize(18)
                .fontColor('#C7C7CC')
            }
            .width('100%')
            .padding({ top: 20, bottom: 20 })
            .onClick(() => this.showPrivacyPolicy())
          }
          .width('100%')
          .padding(24)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .margin({ bottom: 32 }) // 原来功能设置卡片的位置留出一些间距
          .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.04)', offsetY: 2 })
        }
        .padding(16)
      }
      .layoutWeight(1)
      .backgroundColor('#F8F9FA')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F9FA')
  }
}