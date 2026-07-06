# Screen Asset Map

This map follows the product blueprint and asset inventory. Current placeholders are SwiftUI views in `PhoneInTheOtherRoomApp/Views/Components/AssetPlaceholderComponents.swift`.

| Screen | Components | Required assets | Current placeholder | Future asset name |
|---|---|---|---|---|
| Onboarding | OnboardingStep, AssetPlaceholderView | welcome Ollie, goal cards, permission art, first mission art | icon cards | `onboarding_welcome_ollie`, `onboarding_goal_cards`, `onboarding_permissions`, `mission_daily_icon` |
| Home Dashboard | PixelDailyProgress, PixelRoomScene, PixelShortcutTile, DogSpriteView | Ollie idle/happy, home room, dog bed, phone-away motif | SwiftUI room and dog shapes | `dog_idle`, `dog_happy`, `home_room_day`, `home_bed`, `home_phone_away` |
| Focus Setup | FocusRunSetupView, duration buttons, Watch companion card | timer icon, Watch status, focus run preview | existing SwiftUI cards | `icon_device_watch_connected`, `ui_card_focus_setup`, `mission_daily_icon` |
| Put Phone Away | existing Focus Run flow | phone-away instruction art, Watch check, door/path | existing proximity state UI | `home_phone_away`, `icon_device_phone_away`, `icon_device_watch_connected` |
| Active Focus Session | ActiveRunView, IsometricFocusYardView, ProgressRing | Ollie guarding/running, focus path, timer ring, device status | existing SwiftUI yard and timer | `dog_focused`, `dog_running`, `focus_path_simple`, `ui_progress_ring` |
| Session Complete | CompletionView, RewardCard | happy/proud Ollie, reward glow, sheep reveal | existing reward UI plus SwiftUI cards | `dog_proud`, `dog_happy`, `ui_modal_reward_sheep`, `sheep_common_white` |
| Session Interrupted | EarlyEndView | concerned Ollie, gentle warning art | existing interruption view | `dog_concerned`, `ui_error_phone_nearby` |
| Farm Overview | FarmOverviewScreen, FarmTileView, SheepSpriteView | farm background, barn, fence, windmill, sheep variants | gradient farm and asset placeholders | `farm_background_day`, `farm_barn`, `farm_fence`, `farm_windmill`, `sheep_common_white` |
| Sheep Collection | SheepCollectionScreen, SheepDetailScreen, SheepSpriteView | 13 MVP sheep, rarity frames, locked state | SwiftUI sheep shapes | `sheep_common_white`, `sheep_cream`, `sheep_black`, `sheep_golden`, `ui_rarity_frame_common` |
| Farm Upgrades | FarmTileView | pasture, barn, flower patch, training field previews | asset placeholder tiles | `farm_pasture_upgrade`, `farm_barn`, `farm_flower_patch`, `farm_training_field` |
| Decoration Inventory | FarmUtilityScreen, FarmTileView | hay bale, fence, flower patch, signboard, placement slots | asset placeholder tiles | `farm_hay_bale`, `farm_fence`, `farm_flower_patch`, `farm_signboard` |
| Resource Inventory | ResourceRow, AssetPlaceholderView | wool, treats, bones, bells, special tokens | icon placeholders | `icon_reward_wool`, `icon_reward_treat`, `icon_reward_bone`, `icon_reward_bell` |
| Missions | MissionsOverviewScreen, MissionCard, ProgressBar | daily/weekly/achievement/event icons, reward previews | SwiftUI card with SF Symbols | `mission_daily_icon`, `mission_weekly_icon`, `mission_achievement_icon`, `mission_event_icon` |
| Mission Detail | MissionDetailScreen, MissionCard, InfoCard | mission icon, progress asset, reward preview | SwiftUI rows | `ui_card_mission_default`, `ui_progress_bar`, `ui_card_reward_default` |
| Reward Claim | RewardClaimScreen, RewardCard | reward card, wool, cosmetic, badge, decoration | asset placeholder reward cards | `ui_card_reward_default`, `reward_wool_bundle`, `dog_bandana_focus_blue`, `badge_sheep_finder` |
| Doghouse | DoghouseScreen, DogSpriteView, RewardCard | Ollie states, collars, bandanas, hats, badges | SwiftUI dog and reward placeholders | `dog_idle`, `dog_happy`, `dog_collar_default`, `dog_bandana_focus_blue`, `dog_hat_straw` |
| Stats | FocusStatsView, StatsOverviewScreen, StatsCard, FocusSessionCard | stat icons, chart elements, empty state | mock stat cards plus existing Screen Time rows | `icon_stats_focus_minutes`, `ui_chart_weekly_bar`, `ui_empty_stats`, `stats_insight_ollie` |
| Friends | FriendsOverviewScreen | feed icon, herd icon, challenge icon, invite icon | simple mock feed cards | `icon_social_feed`, `icon_social_herd`, `icon_social_challenge`, `icon_social_invite` |
| Settings | SettingsPlaceholderScreen | profile, daily goal, presets, notifications, Watch, privacy | placeholder rows | `icon_settings_profile`, `icon_settings_goal`, `icon_device_watch_connected`, `icon_settings_privacy` |
| Watch Setup | SettingsPlaceholderScreen, existing Watch app | Watch icon, connection states, warning/success | placeholder row plus existing Watch views | `icon_device_watch_connected`, `icon_device_watch_disconnected`, `watch_ollie_face` |
| Screen Time Setup | FocusStatsView, SettingsPlaceholderScreen | shield/privacy icon, permission lock, chart fallback | existing FamilyControls setup plus mock fallback | `icon_permission_lock`, `icon_stats_screen_time`, `ui_empty_stats` |

