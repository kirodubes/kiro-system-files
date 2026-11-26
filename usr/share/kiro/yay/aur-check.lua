-- Kiro: AUR check for yay (kiro-system-files)
--
-- Loaded from ~/.config/yay/init.lua through the line kiro-yay-aur-check manages. yay 13+ runs
-- AURPreInstall once per AUR package base, AUR dependencies included, after the PKGBUILDs are
-- fetched and before its menus, source downloads and builds. kiro-aur-check shows the risky
-- PKGBUILD lines and asks y/N on Danger; a non-zero exit (N, or no terminal to ask) stops yay.
-- A reading aid, not a guarantee.

local check = "/usr/local/bin/kiro-aur-check"

local function quote(text)
  return "'" .. (text:gsub("'", "'\\''")) .. "'"
end

-- gopher-lua (yay) returns the exit status as a number; Lua 5.2+ returns true or nil first.
local function succeeded(status)
  if type(status) == "number" then
    return status == 0
  end
  return status == true
end

yay.create_autocmd("AURPreInstall", {
  desc = "Kiro AUR check (kiro-aur-check)",
  callback = function(event)
    local exe = io.open(check, "r")
    if not exe then
      return
    end
    exe:close()
    local cmd = "PKGBASE=" .. quote(event.match) .. " " .. check .. " " .. quote(event.data.dir)
    if not succeeded(os.execute(cmd)) then
      yay.abort(event.match .. ": build stopped by the AUR check (kiro-aur-check)")
    end
  end,
})
