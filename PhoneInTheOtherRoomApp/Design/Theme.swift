import SwiftUI

enum AppColors {
    static let background = Color(red: 0.98, green: 0.97, blue: 0.92)
    static let paper = Color(red: 0.99, green: 0.985, blue: 0.965)
    static let surface = Color.white
    static let surfaceMuted = Color(red: 0.93, green: 0.91, blue: 0.84)
    static let panel = Color.white
    static let ink = Color(red: 0.12, green: 0.12, blue: 0.10)
    static let secondaryText = Color(red: 0.45, green: 0.45, blue: 0.40)
    static let muted = Color(red: 0.48, green: 0.48, blue: 0.46)
    static let grass = Color(red: 0.34, green: 0.52, blue: 0.27)
    static let grassLight = Color(red: 0.72, green: 0.80, blue: 0.57)
    static let floor = Color(red: 0.82, green: 0.72, blue: 0.58)
    static let wood = Color(red: 0.56, green: 0.34, blue: 0.20)
    static let sky = Color(red: 0.55, green: 0.78, blue: 0.92)
    static let wool = Color(red: 0.94, green: 0.92, blue: 0.84)
    static let sheep = Color(red: 0.92, green: 0.90, blue: 0.82)
    static let coin = Color(red: 0.96, green: 0.72, blue: 0.18)
    static let clay = Color(red: 0.70, green: 0.39, blue: 0.24)
    static let bark = Color(red: 0.30, green: 0.18, blue: 0.11)
    static let amber = Color(red: 0.94, green: 0.68, blue: 0.22)
    static let berry = Color(red: 0.62, green: 0.22, blue: 0.30)
    static let lavender = Color(red: 0.48, green: 0.45, blue: 0.68)
    static let success = Color(red: 0.22, green: 0.57, blue: 0.36)
    static let warning = Color(red: 0.91, green: 0.53, blue: 0.21)
    static let stroke = Color.black
}

/// Backward-compatible aliases used across pixel-styled screens.
enum PixelPalette {
    static let paper = AppColors.paper
    static let ink = AppColors.stroke
    static let muted = AppColors.muted
    static let grass = AppColors.grass
    static let grassLight = AppColors.grassLight
    static let floor = AppColors.floor
    static let wood = AppColors.wood
    static let sky = AppColors.sky
    static let coin = AppColors.coin
    static let sheep = AppColors.sheep
    static let panel = AppColors.panel
}

enum AppGoals {
    /// Rainbow focus star threshold — used as the home daily progress goal.
    static let dailyFocusMinutes = FocusStarTier.rainbow.thresholdMinutes
}

enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 36
}

enum AppRadius {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
}

enum AppTypography {
    static func display(_ size: CGFloat = 28) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }

    static let title = Font.system(.title2, design: .rounded).weight(.black)
    static let headline = Font.system(.headline, design: .rounded).weight(.bold)
    static let body = Font.system(.body, design: .rounded).weight(.medium)
    static let caption = Font.system(.caption, design: .rounded).weight(.semibold)
    static let monoCaption = Font.system(.caption, design: .monospaced).weight(.bold)
}

enum PixelTypography {
    /// Monospaced black — numbers, timers, and pixel labels.
    static func mono(_ style: Font.TextStyle) -> Font {
        .system(style, design: .monospaced).weight(.black)
    }

    /// Rounded bold — section titles and body on pixel screens.
    static func title(_ style: Font.TextStyle) -> Font {
        .system(style, design: .rounded).weight(.bold)
    }
}

func pixelFont(_ style: Font.TextStyle) -> Font {
    PixelTypography.mono(style)
}

enum AppShadows {
    static let cardColor = Color.black.opacity(0.12)
    static let cardRadius: CGFloat = 10
    static let cardY: CGFloat = 5
    static let pixelOffset: CGFloat = 4
}

enum AssetSlot {
    enum Dog {
        static let idle = "dog/dog_idle"
        static let happy = "dog/dog_happy"
        static let sleeping = "dog/dog_sleeping"
        static let focused = "dog/dog_focused"
        static let concerned = "dog/dog_concerned"
        static let proud = "dog/dog_proud"
    }

    enum Sheep {
        static let common = "sheep/sheep_common"
        static let cream = "sheep/sheep_cream"
        static let black = "sheep/sheep_black"
        static let golden = "sheep/sheep_golden"
        static let night = "sheep/sheep_night"
    }

    enum Farm {
        static let backgroundDay = "farm/farm_background_day"
        static let barn = "farm/farm_barn"
        static let fence = "farm/farm_fence"
        static let windmill = "farm/farm_windmill"
        static let hayBale = "farm/farm_hay_bale"
    }

    enum Home {
        static let roomDay = "home/home_room_day"
        static let bed = "home/home_bed"
        static let window = "home/home_window"
        static let door = "home/home_door"
        static let plant = "home/home_plant"
        static let bedtimeMoon = "home/bedtime_moon"
        static let phoneAway = "home/home_phone_away"
    }

    enum Missions {
        static let awayIcon = "missions/mission_away_icon"
        static let dailyIcon = "missions/mission_daily_icon"
        static let weeklyIcon = "missions/mission_weekly_icon"
        static let achievementIcon = "missions/mission_achievement_icon"
    }

    enum Stats {
        static let phone = "stats/stats_phone"
        static let watch = "stats/stats_watch"
    }

    enum UI {
        static let progressRing = "ui/ui_progress_ring"
        static let rewardCard = "ui/ui_reward_card"
        static let emptyState = "ui/ui_empty_state"
    }
}

func focusStarColor(for tier: FocusStarTier) -> Color {
    switch tier {
    case .silver: return Color(red: 0.82, green: 0.84, blue: 0.84)
    case .gold: return Color(red: 0.98, green: 0.77, blue: 0.20)
    case .diamond: return Color(red: 0.38, green: 0.82, blue: 0.95)
    case .rainbow: return AppColors.amber
    }
}
