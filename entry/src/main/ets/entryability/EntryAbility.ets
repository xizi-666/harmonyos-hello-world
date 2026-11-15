import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { preferences } from '@kit.ArkData';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    hilog.info(DOMAIN, 'RefChecker', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'RefChecker', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'RefChecker', '%{public}s', 'Ability onWindowStageCreate');
    this.loadStoreAndShow(windowStage);
  }

  /** 读取本地保存的引用条目，存入 AppStorage 后加载页面 */
  private async loadStoreAndShow(windowStage: window.WindowStage): Promise<void> {
    let raw: string = '';
    try {
      const pref: preferences.Preferences = await preferences.getPreferences(this.context, 'ref_store');
      const value: preferences.ValueType = await pref.get('citations_v1', '');
      raw = value as string;
    } catch (e) {
      raw = '';
      hilog.error(DOMAIN, 'RefChecker', 'load store failed: %{public}s', JSON.stringify(e));
    }
    AppStorage.setOrCreate<string>('citations_raw', raw);
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'RefChecker', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'RefChecker', '%{public}s', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'RefChecker', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'RefChecker', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'RefChecker', '%{public}s', 'Ability onBackground');
  }
}
