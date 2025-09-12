import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  /**
   * Ability 创建阶段回调。
   * 作用：进行应用级初始化（如主题/色彩模式等）。
   * @param want 应用启动参数
   * @param launchParam 启动参数
   */
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'onCreate');
  }

  /**
   * Ability 销毁阶段回调。
   * 作用：释放资源、打印日志。
   */
  onDestroy(): void {
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'onDestroy');
  }

  /**
   * 窗口创建回调：设置主页面
   * @param windowStage 主窗口阶段对象
   */
  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'EntryAbility', 'Failed to load content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'EntryAbility', 'Succeeded in loading the content.');
    });
  }

  /**
   * 窗口销毁回调。
   * 作用：释放与窗口相关的资源。
   */
  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'onWindowStageDestroy');
  }

  /**
   * 前台回调。
   * 作用：可在此恢复前台所需状态。
   */
  onForeground(): void {
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'onForeground');
  }

  /**
   * 后台回调。
   * 作用：可在此暂停非关键逻辑、节省资源。
   */
  onBackground(): void {
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'onBackground');
  }
}