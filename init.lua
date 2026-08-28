-- ==========================================
-- 설정
-- ==========================================

local running = false
local macroRunning = false

local sequenceTimer = nil
local scanTimer = nil
local noMacroTimer = nil

local currentStep = 1
local activeSteps = nil

local ocrBusy = false
local lastAction = nil
local kActionTextDetected = false
local kActionRunning = false
local kActionTimer = nil
local kActionCount = 0
local questCompletedDetected = false
local shortcutTextDetected = false
local shortcutRunning = false
local shortcutTimer = nil
local shortcutCount = 0

local kRunning = false
local kTimer = nil

local KEY_HOLD_TIME = 0.1
local SCAN_INTERVAL = 0.8
local NO_MACRO_TIMEOUT = 15

local TESSERACT_PATH = "/opt/homebrew/bin/tesseract"

local OCR_IMAGE_PATH =
    os.getenv("HOME") .. "/.hammerspoon/quest_ocr.png"

local function showStatus(message)

    hs.alert.show("퀘스트 매크로: " .. message)

end


-- ==========================================
-- 키 입력
-- ==========================================

local function pressKey(key, holdTime, callback)

    holdTime = holdTime or KEY_HOLD_TIME

    hs.eventtap.event.newKeyEvent({}, key, true):post()

    hs.timer.doAfter(holdTime, function()

        hs.eventtap.event.newKeyEvent({}, key, false):post()

        if callback then
            callback()
        end

    end)
end


local startMacro
local scheduleNoMacroFallback


-- ==========================================
-- 퀘스트별 매크로
-- ==========================================

local function openOven()

    return {

        {key = "k",     wait = 0.5},
        {key = "space", wait = 1},

        {key = "q",     wait = 0.5},
        {key = "q",     wait = 6},

        {key = "k",     wait = 0},

        {key = "q",     wait = 1},
     

    }

end


local function openBag()

    return {
        
        {key = "k",     wait = 0},
        {key = "space", wait = 1},

        {key = "1",     wait = 1},
        {key = "2",     wait = 1},

        {key = "tab",   wait = 1},
        {key = "tab",   wait = 1},
        {key = "k",     wait = 1},
        

    }

end


local function openCookie()

    return {

        {key = "k",     wait = 0},
        {key = "space", wait = 1},

        {key = "e",     wait = 2},

        {key = "tab",   wait = 1},
        {key = "tab",   wait = 1},
        {key = "tab",   wait = 0.5},
        {key = "k",     wait = 1},


    }

end


local function openPet()

    return {

        {key = "k",     wait = 0},
        {key = "space", wait = 1},

        {key = "e",     wait = 2},

        {key = "tab",   wait = 1},
        {key = "tab",   wait = 0.5},
        {key = "tab",   wait = 0.5},
        {key = "k",     wait = 1},

    }

end


-- ==========================================
-- 매크로 실행
-- ==========================================

local function finishMacro()

    macroRunning = false
    activeSteps = nil
    currentStep = 1

    if running then
        scheduleNoMacroFallback()
    end

    showStatus("매크로 완료")
    print("매크로 완료")

end


scheduleNoMacroFallback = function()

    if noMacroTimer then
        noMacroTimer:stop()
    end

    noMacroTimer = hs.timer.doAfter(NO_MACRO_TIMEOUT, function()

        noMacroTimer = nil

        if running and not macroRunning and not kActionRunning then
            startMacro(
                {
                    {key = "tab", wait = 1},
                    {key = "tab", wait = 1},
                    {key = "tab", wait = 1}
                },
                "인식 실패 탭"
            )
        end

    end)

end


local function runNextStep()

    if not running or not macroRunning then
        return
    end

    local step = activeSteps[currentStep]

    if not step then

        finishMacro()
        return

    end

    pressKey(step.key, KEY_HOLD_TIME, function()

        if not running or not macroRunning then
            return
        end

        currentStep = currentStep + 1

        sequenceTimer =
            hs.timer.doAfter(step.wait, runNextStep)

    end)

end


startMacro = function(steps, actionName)

    if macroRunning or kActionRunning then
        return
    end

    if noMacroTimer then
        noMacroTimer:stop()
        noMacroTimer = nil
    end

    macroRunning = true

    activeSteps = steps
    currentStep = 1
    lastAction = actionName

    showStatus(actionName .. " 매크로 시작")

    print("매크로 시작: " .. actionName)

    runNextStep()

end


-- ==========================================
-- OCR 대상 모니터
-- ==========================================

local function getGameScreen()

    local screen = hs.screen.find("LG FULL HD")

    if not screen then

        print("ERROR: LG FULL HD 모니터를 찾지 못했습니다.")
        showStatus("LG FULL HD 모니터를 찾지 못했습니다")

        return nil

    end

    return screen

end


-- ==========================================
-- OCR 결과와 매크로 연결
--
-- 테스트할 때는 일단 쿠키만 등록
-- ==========================================

local QUEST_ACTIONS = {

    {
        keyword = "쿠키",
        action = "쿠키",
        macro = openCookie
    },

    {
        keyword = "가방",
        action = "가방",
        macro = openBag
    },

    {
        keyword = "오븐",
        action = "오븐",
        macro = openOven
    },

    {
        keyword = "펫",
        action = "펫",
        macro = openPet
    },

}


-- ==========================================
-- OCR 결과 처리
-- ==========================================

local function startKActionMacro()

    if kActionRunning or shortcutRunning or macroRunning or kRunning then
        return
    end

    if noMacroTimer then
        noMacroTimer:stop()
        noMacroTimer = nil
    end

    kActionRunning = true
    kActionCount = 0

    showStatus("K 3회 매크로 시작")

    local function pressKActionKey()

        kActionCount = kActionCount + 1
        pressKey("k")

        if kActionCount >= 3 then

            if kActionTimer then
                kActionTimer:stop()
                kActionTimer = nil
            end

            kActionRunning = false
            showStatus("K 3회 매크로 완료")
            print("K 3회 매크로 완료")

        end

    end

    pressKActionKey()

    kActionTimer = hs.timer.doEvery(1, pressKActionKey)

end


local function startShortcutMacro()

    if shortcutRunning or kActionRunning or macroRunning or kRunning then
        return
    end

    if noMacroTimer then
        noMacroTimer:stop()
        noMacroTimer = nil
    end

    shortcutRunning = true
    shortcutCount = 0

    showStatus("바로가기 탭 매크로 시작")

    local function pressShortcutKey()

        shortcutCount = shortcutCount + 1
        pressKey("tab")

        if shortcutCount >= 3 then

            if shortcutTimer then
                shortcutTimer:stop()
                shortcutTimer = nil
            end

            shortcutRunning = false
            showStatus("바로가기 탭 매크로 완료")
            print("바로가기 탭 매크로 완료")

        end

    end

    pressShortcutKey()

    shortcutTimer = hs.timer.doEvery(0.5, pressShortcutKey)

end

local function handleQuestText(text)

    text = text or ""

    text = text:gsub("%s+", " ")

    local hasKActionText =
        text:find("반복", 1, true) ~= nil
        or text:find("처치", 1, true) ~= nil
        or text:find("클리어", 1, true) ~= nil
    local hasShortcutText = text:find("바로가기", 1, true) ~= nil

    if hasShortcutText and not shortcutTextDetected then

        print("'바로가기' 텍스트 발견: Tab 3회 입력")
        startShortcutMacro()

    end

    shortcutTextDetected = hasShortcutText

    if hasShortcutText then
        return
    end

    if hasKActionText and not kActionTextDetected then

        print("'반복', '처치' 또는 '클리어' 텍스트 발견: K 3회 입력")
        startKActionMacro()

    end

    kActionTextDetected = hasKActionText

    if hasKActionText then
        return
    end

    print("--------------------------------")
    print("OCR 결과:")
    print(text)
    print("--------------------------------")

    for _, item in ipairs(QUEST_ACTIONS) do

        if text:find(item.keyword, 1, true) then

            print("퀘스트 발견: " .. item.keyword)

            if not macroRunning then

                startMacro(
                    item.macro(),
                    item.action
                )

            end

            return

        end

    end

    print("일치하는 퀘스트 없음")

end


-- ==========================================
-- OCR 실행
-- ==========================================
local function isQuestCompleted(image)

    if not image then
        return false
    end

    local size = image:size()
    local width = size.w
    local height = size.h

    local yellowCount = 0
    local sampleCount = 0

    -- 일정 간격으로 픽셀 샘플링
    local sampleStep = 8

    for y = 0, height - 1, sampleStep do
        for x = 0, width - 1, sampleStep do

            local color = image:colorAt(
                hs.geometry.point(x, y)
            )

            if color then

                local r = (color.red or 0) * 255
                local g = (color.green or 0) * 255
                local b = (color.blue or 0) * 255

                sampleCount = sampleCount + 1

                -- 완료 상태의 밝은 노란색/주황색 계열
                if r > 180
                    and g > 120
                    and b < 100
                    and r > b * 2 then

                    yellowCount = yellowCount + 1
                end

            end
        end
    end

    if sampleCount == 0 then
        return false
    end

    local ratio = yellowCount / sampleCount

    print(
        string.format(
            "완료 색상 비율: %.1f%%",
            ratio * 100
        )
    )

    -- 노란색 계열이 20% 이상이면 완료 상태
    return ratio >= 0.20
end

local function scanQuest()

    if not running then
        return
    end

    -- 퀘스트 매크로 실행 중이면 OCR 금지
    if macroRunning then
        return
    end

    -- K 매크로 실행 중이면 OCR 금지
    if kRunning then
        return
    end

    -- 처치 매크로 실행 중이면 OCR과 다른 매크로 금지
    if kActionRunning or shortcutRunning then
        return
    end

    if ocrBusy then
        return
    end

    ocrBusy = true

    print("OCR 검사 시작")


    -- -----------------------------
    -- 게임 모니터
    -- -----------------------------

    local screen = getGameScreen()

    if not screen then

        ocrBusy = false
        return

    end


    local frame = screen:frame()

    print(
        string.format(
            "게임 화면: x=%.0f y=%.0f w=%.0f h=%.0f",
            frame.x,
            frame.y,
            frame.w,
            frame.h
        )
    )


    -- -----------------------------
    -- OCR 영역
    -- -----------------------------

local questRect = hs.geometry.rect(
    frame.w * 0.65,
    frame.h * 0.53,
    frame.w * 0.35,
    frame.h * 0.12
)


    print(
        string.format(
            "OCR 영역: x=%.0f y=%.0f w=%.0f h=%.0f",
            questRect.x,
            questRect.y,
            questRect.w,
            questRect.h
        )
    )


    -- -----------------------------
    -- 화면 캡처
    -- -----------------------------

    local image = screen:snapshot(questRect)

    if not image then

        print("ERROR: 화면 캡처 실패")
        showStatus("화면 캡처 실패")

        ocrBusy = false
        return

    end


    print("화면 캡처 성공")

    if isQuestCompleted(image) then

    print("퀘스트 완료 상태 감지")

    if not questCompletedDetected then
        questCompletedDetected = true
        showStatus("퀘스트 완료 감지")
        print("완료 처리를 위해 K 3회 입력")
        startKActionMacro()
    end

    print("OCR 및 퀘스트 매크로 실행을 건너뜁니다.")

    ocrBusy = false
    return

end

questCompletedDetected = false
print("퀘스트 미완료 상태")

    -- -----------------------------
    -- 이미지 저장
    -- -----------------------------

    local saved =
        image:saveToFile(
            OCR_IMAGE_PATH,
            true,
            "PNG"
        )


    if not saved then

        print("ERROR: OCR 이미지 저장 실패")
        showStatus("OCR 이미지 저장 실패")

        ocrBusy = false
        return

    end


    print("OCR 이미지 저장 성공:")
    print(OCR_IMAGE_PATH)


    -- -----------------------------
    -- Tesseract
    -- -----------------------------

    -- ==========================================
-- Tesseract
-- ==========================================

local task = hs.task.new(

    TESSERACT_PATH,

    function(exitCode, stdOut, stdErr)

        ocrBusy = false

        print("Tesseract 종료")
        print("Exit code: " .. tostring(exitCode))

        if stdErr and stdErr ~= "" then
            print("Tesseract STDERR:")
            print(stdErr)
        end

        if exitCode ~= 0 then
            print("ERROR: Tesseract 실행 실패")
            showStatus("Tesseract 실행 실패")
            return
        end

        handleQuestText(stdOut)

    end,

    {
        OCR_IMAGE_PATH,
        "stdout",
        "-l",
        "kor+eng",
        "--psm",
        "6"
    }

)


if not task then

    print("ERROR: hs.task 생성 실패")
    showStatus("OCR 작업 생성 실패")

    ocrBusy = false
    return

end


print("Tesseract 실행")

task:start()

end


-- ==========================================
-- K 단독 매크로
--
-- ⌘ + Shift + L
-- ==========================================

local function pressK()

    hs.eventtap.event.newKeyEvent(
        {},
        "k",
        true
    ):post()

    hs.timer.doAfter(0.1, function()

        hs.eventtap.event.newKeyEvent(
            {},
            "k",
            false
        ):post()

    end)

end


hs.hotkey.bind(
    {"cmd", "shift"},
    "L",
    function()

        kRunning = not kRunning

        if kRunning then

            showStatus("K 매크로 시작")

            pressK()

            kTimer =
                hs.timer.doEvery(
                    2,
                    pressK
                )

        else

            if kTimer then
                kTimer:stop()
                kTimer = nil
            end

            showStatus("K 매크로 중지")

        end

    end
)


-- ==========================================
-- 퀘스트 OCR 매크로
--
-- ⌘ + Shift + K
-- ==========================================

hs.hotkey.bind(
    {"cmd", "shift"},
    "K",
    function()

        running = not running

        if running then

            macroRunning = false
            kActionTextDetected = false
            questCompletedDetected = false
            shortcutTextDetected = false
            currentStep = 1
            lastAction = nil

            showStatus("시작")

            print("===== QUEST MACRO START =====")

            scheduleNoMacroFallback()

            scanTimer =
                hs.timer.doEvery(
                    SCAN_INTERVAL,
                    scanQuest
                )

            scanQuest()

        else

            macroRunning = false
            ocrBusy = false

            if noMacroTimer then
                noMacroTimer:stop()
                noMacroTimer = nil
            end

            if kActionTimer then
                kActionTimer:stop()
                kActionTimer = nil
            end

            kActionRunning = false

            if shortcutTimer then
                shortcutTimer:stop()
                shortcutTimer = nil
            end

            shortcutRunning = false

            if sequenceTimer then

                sequenceTimer:stop()
                sequenceTimer = nil

            end

            if scanTimer then

                scanTimer:stop()
                scanTimer = nil

            end

            showStatus("중지")

            print("===== QUEST MACRO STOP =====")

        end

    end
)