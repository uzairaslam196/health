// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/health"
import topbar from "../vendor/topbar"

// Custom hooks
const Hooks = {
  RoastSession: {
    mounted() {
      this.roomId = this.el.dataset.roomId
      this.storageKey = this.roomId ? `roast_session:${this.roomId}` : 'roast_session'
      this.passwordKey = this.roomId ? `roast_password:${this.roomId}` : 'roast_password'
      this.restoreFromStorage()

      this.handleEvent('persist_session', (data) => {
        if (!data || !data.player_id || !data.username) return
        localStorage.setItem(this.storageKey, JSON.stringify({
          player_id: data.player_id,
          username: data.username
        }))
      })

      this.handleEvent('persist_password', (data) => {
        if (!data || !data.password_verified) return
        localStorage.setItem(this.passwordKey, JSON.stringify({
          password_verified: true
        }))
      })
    },

    restoreFromStorage() {
      try {
        // Restore password verification first
        const passwordData = localStorage.getItem(this.passwordKey)
        if (passwordData) {
          const parsed = JSON.parse(passwordData)
          if (parsed && parsed.password_verified) {
            this.pushEvent('restore_password', parsed)
          }
        }

        // Then restore session
        const stored = localStorage.getItem(this.storageKey)
        if (!stored) return
        const data = JSON.parse(stored)
        if (!data || !data.player_id || !data.username) return
        this.pushEvent('restore_session', data)
      } catch (_) {}
    }
  },
  ScrollBottom: {
    mounted() {
      this.el.scrollTop = this.el.scrollHeight
    },
    updated() {
      this.el.scrollTop = this.el.scrollHeight
    }
  },

  HipMover: {
    mounted() {
      this.butt = document.getElementById('butt-character')
      this.theButt = document.getElementById('the-butt')
      this.buttHole = this.el.querySelector('.butt-hole')
      this.bloodContainer = document.getElementById('blood-container')
      this.arena = this.el
      this.hitCount = 0
      this.holeAudio = null
      this.holeAudioUnlocked = false

      // Butt position (percentage)
      this.x = 50
      this.y = 50
      this.vx = 2
      this.vy = 1.5
      this.time = 0

      // Aim/crosshair position (pixels)
      this.aimX = 0
      this.aimY = 0
      this.isAiming = false

      // Create crosshair element
      this.crosshair = document.createElement('div')
      this.crosshair.className = 'crosshair'
      this.crosshair.innerHTML = '+'
      this.arena.appendChild(this.crosshair)

      // Create gun element at bottom
      this.gun = document.createElement('div')
      this.gun.className = 'gun'
      this.gun.innerHTML = '🔫'
      this.arena.appendChild(this.gun)

      // Start butt animation
      this.startAnimation()

      // Start auto-fire when aiming
      this.fireInterval = null

      // Track mouse/touch position for aiming
      this.arena.addEventListener('mousemove', (e) => this.handleAim(e))
      this.arena.addEventListener('mouseenter', () => this.startFiring())
      this.arena.addEventListener('mouseleave', () => this.stopFiring())

      this.arena.addEventListener('touchstart', (e) => {
        e.preventDefault()
        this.startFiring()
        this.handleTouchAim(e)
      })
      this.arena.addEventListener('touchmove', (e) => {
        e.preventDefault()
        this.handleTouchAim(e)
      })
      this.arena.addEventListener('touchend', () => this.stopFiring())

      // Listen for hit/miss events from server
      this.handleEvent('hit', (data) => this.onHit(data))
      this.handleEvent('miss', (data) => this.onMiss(data))

      // Prepare audio once for reliable playback
      this.initHoleAudio()
    },

    startAnimation() {
      this.interval = setInterval(() => {
        this.move()
        this.butt.style.left = `${this.x}%`
        this.butt.style.top = `${this.y}%`
      }, 50)
    },

    move() {
      this.time += 0.1
      const damageLevel = parseInt(this.el.dataset.damageLevel) || 0

      if (damageLevel < 2) {
        this.x += Math.sin(this.time) * 0.8
        this.y += Math.cos(this.time * 0.7) * 0.5
      } else if (damageLevel < 4) {
        this.x += Math.sin(this.time * 1.5) * 1.5 + (Math.random() - 0.5) * 2
        this.y += Math.cos(this.time * 1.2) * 1.2 + (Math.random() - 0.5) * 1.5
      } else {
        this.x += Math.sin(this.time * 2) * 2.5 + (Math.random() - 0.5) * 4
        this.y += Math.cos(this.time * 1.8) * 2 + (Math.random() - 0.5) * 3
      }

      if (this.x < 20) { this.x = 20; this.vx *= -1 }
      if (this.x > 60) { this.x = 60; this.vx *= -1 }
      if (this.y < 15) { this.y = 15; this.vy *= -1 }
      if (this.y > 45) { this.y = 45; this.vy *= -1 }
    },

    handleAim(e) {
      const rect = this.arena.getBoundingClientRect()
      this.aimX = e.clientX - rect.left
      this.aimY = e.clientY - rect.top
      this.updateCrosshair()
      this.updateGunAngle()
    },

    handleTouchAim(e) {
      const touch = e.touches[0]
      const rect = this.arena.getBoundingClientRect()
      this.aimX = touch.clientX - rect.left
      this.aimY = touch.clientY - rect.top
      this.updateCrosshair()
      this.updateGunAngle()
    },

    updateCrosshair() {
      this.crosshair.style.left = `${this.aimX}px`
      this.crosshair.style.top = `${this.aimY}px`
    },

    updateGunAngle() {
      const rect = this.arena.getBoundingClientRect()
      const gunX = rect.width / 2
      const gunY = rect.height - 30
      const angle = Math.atan2(this.aimY - gunY, this.aimX - gunX) * 180 / Math.PI
      this.gun.style.transform = `translateX(-50%) rotate(${angle + 90}deg)`
    },

    startFiring() {
      if (this.fireInterval) return
      this.isAiming = true
      this.crosshair.classList.add('active')
      this.unlockHoleAudio()

      // Fire bullets every 150ms
      this.fireInterval = setInterval(() => {
        this.fireBullet()
      }, 150)
    },

    stopFiring() {
      this.isAiming = false
      this.crosshair.classList.remove('active')
      if (this.fireInterval) {
        clearInterval(this.fireInterval)
        this.fireInterval = null
      }
    },

    fireBullet() {
      const rect = this.arena.getBoundingClientRect()
      const startX = rect.width / 2
      const startY = rect.height - 40

      // Create bullet
      const bullet = document.createElement('div')
      bullet.className = 'bullet'
      bullet.style.left = `${startX}px`
      bullet.style.top = `${startY}px`
      this.arena.appendChild(bullet)

      // Calculate trajectory
      const targetX = this.aimX
      const targetY = this.aimY
      const dx = targetX - startX
      const dy = targetY - startY
      const distance = Math.sqrt(dx * dx + dy * dy)
      const speed = 15
      const vx = (dx / distance) * speed
      const vy = (dy / distance) * speed

      let currentX = startX
      let currentY = startY
      let prevX = startX
      let prevY = startY

      const bulletInterval = setInterval(() => {
        prevX = currentX
        prevY = currentY
        currentX += vx
        currentY += vy
        bullet.style.left = `${currentX}px`
        bullet.style.top = `${currentY}px`

        // Check if bullet is out of bounds
        if (currentX < 0 || currentX > rect.width || currentY < 0 || currentY > rect.height) {
          clearInterval(bulletInterval)
          bullet.remove()
          return
        }

        // Check if bullet hit the butt
        if (!this.theButt) {
          console.log('the-butt element not found!')
          this.theButt = this.el.querySelector('#the-butt')
        }
        if (!this.buttHole) {
          this.buttHole = this.el.querySelector('.butt-hole')
        }
        if (!this.theButt) {
          return
        }
        const buttRect = this.theButt.getBoundingClientRect()
        const holeRect = this.buttHole ? this.buttHole.getBoundingClientRect() : null
        const bulletAbsX = rect.left + currentX
        const bulletAbsY = rect.top + currentY
        // Check hit on butt area - distinguish between hole and cheeks
        const buttCenterX = buttRect.left + buttRect.width / 2
        const buttCenterY = buttRect.top + buttRect.height / 2
        const holeCenterX = holeRect ? holeRect.left + holeRect.width / 2 : buttCenterX
        const holeCenterY = holeRect ? holeRect.top + holeRect.height / 2 : buttRect.top + buttRect.height * 0.52
        const holeHitPadding = 60
        const holeRadius = holeRect
          ? Math.min(holeRect.width, holeRect.height) / 2 + holeHitPadding
          : Math.min(buttRect.width, buttRect.height) * 0.2
        const holeRadiusX = holeRect ? holeRect.width / 2 + holeHitPadding : holeRadius
        const holeRadiusY = holeRect ? holeRect.height / 2 + holeHitPadding : holeRadius
        const holeEllipseHit = holeRect
          ? (
            Math.pow(bulletAbsX - holeCenterX, 2) / Math.pow(holeRadiusX, 2) +
            Math.pow(bulletAbsY - holeCenterY, 2) / Math.pow(holeRadiusY, 2)
          ) <= 1
          : false
        const prevAbsX = rect.left + prevX
        const prevAbsY = rect.top + prevY
        const segDx = bulletAbsX - prevAbsX
        const segDy = bulletAbsY - prevAbsY
        const segLenSq = segDx * segDx + segDy * segDy
        const t = segLenSq > 0
          ? Math.max(0, Math.min(1, ((holeCenterX - prevAbsX) * segDx + (holeCenterY - prevAbsY) * segDy) / segLenSq))
          : 0
        const closestX = prevAbsX + segDx * t
        const closestY = prevAbsY + segDy * t
        const distToHoleSegment = Math.sqrt(
          Math.pow(closestX - holeCenterX, 2) +
          Math.pow(closestY - holeCenterY, 2)
        )
        const holeRectHit = holeRect
          ? (() => {
            const rectLeft = holeRect.left - holeHitPadding
            const rectRight = holeRect.right + holeHitPadding
            const rectTop = holeRect.top - holeHitPadding
            const rectBottom = holeRect.bottom + holeHitPadding

            const pointInRect = (x, y) =>
              x >= rectLeft && x <= rectRight && y >= rectTop && y <= rectBottom

            if (pointInRect(prevAbsX, prevAbsY) || pointInRect(bulletAbsX, bulletAbsY)) {
              return true
            }

            const edges = [
              [rectLeft, rectTop, rectRight, rectTop],
              [rectRight, rectTop, rectRight, rectBottom],
              [rectRight, rectBottom, rectLeft, rectBottom],
              [rectLeft, rectBottom, rectLeft, rectTop]
            ]

            const intersects = (x1, y1, x2, y2, x3, y3, x4, y4) => {
              const denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
              if (denom === 0) return false
              const t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
              const u = ((x1 - x3) * (y1 - y2) - (y1 - y3) * (x1 - x2)) / denom
              return t >= 0 && t <= 1 && u >= 0 && u <= 1
            }

            return edges.some(([x3, y3, x4, y4]) =>
              intersects(prevAbsX, prevAbsY, bulletAbsX, bulletAbsY, x3, y3, x4, y4)
            )
          })()
          : false
        const cheekRadius = Math.max(110, Math.min(buttRect.width, buttRect.height) * 0.5)

        const distToHoleCenter = Math.sqrt(
          Math.pow(bulletAbsX - holeCenterX, 2) +
          Math.pow(bulletAbsY - holeCenterY, 2)
        )
        const distToButtCenter = Math.sqrt(
          Math.pow(bulletAbsX - buttCenterX, 2) +
          Math.pow(bulletAbsY - buttCenterY, 2)
        )

        console.log('Bullet position:', bulletAbsX, bulletAbsY)
        console.log('Hole center:', holeCenterX, holeCenterY)
        console.log('Distance to hole:', distToHoleCenter)

        // Check if hit inner hole (actual damage)
        if (holeRectHit || holeEllipseHit || distToHoleSegment < holeRadius || (!holeRect && distToHoleCenter < holeRadius)) {
          console.log('🎯 HOLE HIT! Distance:', distToHoleCenter)
          clearInterval(bulletInterval)
          bullet.classList.add('hit')
          setTimeout(() => bullet.remove(), 100)

          // Play audio for hole hit
          this.playHoleHitAudio()

          // Notify server of REAL hit (health decreases)
          const x = (currentX / rect.width)
          const y = (currentY / rect.height)
          console.log('Sending hit_attempt to server')
          this.pushEvent('hit_attempt', { x, y, forced_hit: true })
          return
        }
        // Check if hit cheeks (visual only, no health damage)
        else if (distToButtCenter < cheekRadius) {
          console.log('👋 CHEEK HIT! Distance:', distToButtCenter)
          clearInterval(bulletInterval)
          bullet.classList.add('hit')
          setTimeout(() => bullet.remove(), 100)

          // Visual feedback only - no health damage
          this.onCheekHit()
          return
        }
      }, 16)

      // Cleanup after 2 seconds max
      setTimeout(() => {
        clearInterval(bulletInterval)
        bullet.remove()
      }, 2000)
    },

    onHit(data) {
      this.hitCount++
      this.spurtBlood()
      this.addHandprint()

      const damageLevel = Math.min(5, Math.floor(this.hitCount / 3))
      if (this.theButt) {
        this.theButt.dataset.damage = damageLevel
        this.theButt.classList.add('hit-flash')
        setTimeout(() => this.theButt.classList.remove('hit-flash'), 200)
      }

      const pool = this.el.querySelector('.blood-pool')
      if (pool) {
        const poolWidth = Math.min(180, 20 + this.hitCount * 8)
        pool.style.width = `${poolWidth}px`
      }
    },

    spurtBlood() {
      if (!this.bloodContainer) return

      for (let i = 0; i < 3; i++) {
        const spurt = document.createElement('div')
        spurt.className = 'blood-spurt'
        spurt.style.animationDelay = `${i * 0.08}s`
        spurt.style.transform = `translateX(-50%) rotate(${-25 + Math.random() * 50}deg)`
        this.bloodContainer.appendChild(spurt)
        setTimeout(() => spurt.remove(), 600)
      }

      const drip = document.createElement('div')
      drip.className = 'blood-drip'
      drip.style.left = `${45 + Math.random() * 10}%`
      this.bloodContainer.appendChild(drip)
      setTimeout(() => drip.remove(), 1200)
    },

    addHandprint() {
      if (!this.theButt) return

      const handprint = document.createElement('div')
      handprint.className = 'handprint'
      const isLeft = Math.random() > 0.5
      handprint.style.top = `${15 + Math.random() * 50}%`
      handprint.style.left = isLeft ? `${5 + Math.random() * 25}%` : `${55 + Math.random() * 25}%`
      handprint.style.transform = `rotate(${-35 + Math.random() * 70}deg)`
      this.theButt.appendChild(handprint)
    },

    onMiss(data) {
      this.arena.classList.add('miss-shake')
      setTimeout(() => this.arena.classList.remove('miss-shake'), 300)
    },

    onCheekHit() {
      // Hit the butt cheek but not the hole - visual feedback only
      if (this.theButt) {
        this.theButt.classList.add('hit-flash')
        setTimeout(() => this.theButt.classList.remove('hit-flash'), 200)
      }
      // Add a smaller handprint on the cheek
      this.addHandprint()
    },

    playHoleHitAudio() {
      // Play audio when center hole is hit
      console.log('🔊 Playing hole hit audio...')
      try {
        this.initHoleAudio()
        if (!this.holeAudio) return
        this.holeAudio.currentTime = 0
        this.holeAudio.play()
          .then(() => console.log('✅ Audio played successfully'))
          .catch(err => console.error('❌ Audio play failed:', err))
      } catch (err) {
        console.error('❌ Audio error:', err)
      }
    },

    initHoleAudio() {
      if (this.holeAudio) return
      this.holeAudio = new Audio('/audio/voice.wav')
      this.holeAudio.volume = 0.8
      this.holeAudio.preload = 'auto'
    },

    unlockHoleAudio() {
      if (!this.holeAudio || this.holeAudioUnlocked) return
      const playPromise = this.holeAudio.play()
      if (!playPromise) return

      playPromise
        .then(() => {
          this.holeAudio.pause()
          this.holeAudio.currentTime = 0
          this.holeAudioUnlocked = true
        })
        .catch(() => {})
    },

    destroyed() {
      if (this.interval) clearInterval(this.interval)
      if (this.fireInterval) clearInterval(this.fireInterval)
      if (this.crosshair) this.crosshair.remove()
      if (this.gun) this.gun.remove()
    }
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

