/**
 * Chart Download Helper for Mobile App
 * این فایل برای صفحات چارت PHP استفاده می‌شود
 */

;(() => {
  // Helper function برای SVG به base64
  function svgToBase64(svgElement) {
    const serializer = new XMLSerializer()
    const svgString = serializer.serializeToString(svgElement)
    return btoa(unescape(encodeURIComponent(svgString)))
  }

  // Helper function برای Canvas به base64
  function canvasToBase64(canvas) {
    return canvas.toDataURL("image/png").split(",")[1]
  }

  // Helper function برای HTML content به SVG
  function htmlToSvgBase64(container) {
    const svg = container.querySelector("svg")
    if (svg) {
      return svgToBase64(svg)
    }
    return null
  }

  // دانلود SVG
  window.downloadChartSVG = (filename = "chart.svg") => {
    try {
      const container =
        document.getElementById("bubble-chart-container") ||
        document.querySelector("svg")?.parentElement ||
        document.body

      const base64Content = htmlToSvgBase64(container)

      if (!base64Content) {
        alert("خطا: نمودار پیدا نشد")
        return
      }

      // ارسال به Flutter
      if (window.FileDownloader) {
        const message = `${base64Content}|${filename}|svg`
        window.FileDownloader.postMessage(message)
      } else {
        alert("خطا: سیستم دانلود در دسترس نیست")
      }
    } catch (error) {
      console.error("خطا در دانلود SVG:", error)
      alert(`خطا: ${error.message}`)
    }
  }

  // دانلود PNG
  window.downloadChartPNG = (filename = "chart.png") => {
    try {
      const container =
        document.getElementById("bubble-chart-container") ||
        document.querySelector("svg")?.parentElement ||
        document.body

      const svg = container.querySelector("svg")
      if (!svg) {
        alert("خطا: نمودار پیدا نشد")
        return
      }

      // SVG را به Canvas تبدیل کن
      const canvas = document.createElement("canvas")
      const ctx = canvas.getContext("2d")
      const svgRect = svg.getBoundingClientRect()

      canvas.width = svgRect.width
      canvas.height = svgRect.height

      const svgData = new XMLSerializer().serializeToString(svg)
      const img = new Image()

      img.onload = () => {
        ctx.fillStyle = "#ffffff"
        ctx.fillRect(0, 0, canvas.width, canvas.height)
        ctx.drawImage(img, 0, 0)

        const base64Content = canvas.toDataURL("image/png").split(",")[1]

        // ارسال به Flutter
        if (window.FileDownloader) {
          const message = `${base64Content}|${filename}|png`
          window.FileDownloader.postMessage(message)
        }
      }

      img.onerror = () => {
        alert("خطا: نمودار قابل تبدیل نیست")
      }

      img.src = "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svgData)))
    } catch (error) {
      console.error("خطا در دانلود PNG:", error)
      alert(`خطا: ${error.message}`)
    }
  }

  // دانلود PDF (ساده - فقط SVG به صورت PDF)
  window.downloadChartPDF = (filename = "chart.pdf") => {
    try {
      const container =
        document.getElementById("bubble-chart-container") ||
        document.querySelector("svg")?.parentElement ||
        document.body

      const svg = container.querySelector("svg")
      if (!svg) {
        alert("خطا: نمودار پیدا نشد")
        return
      }

      // ابتدا به PNG تبدیل کن سپس به عنوان PDF ارسال کن
      const canvas = document.createElement("canvas")
      const ctx = canvas.getContext("2d")
      const svgRect = svg.getBoundingClientRect()

      canvas.width = svgRect.width
      canvas.height = svgRect.height

      const svgData = new XMLSerializer().serializeToString(svg)
      const img = new Image()

      img.onload = () => {
        ctx.fillStyle = "#ffffff"
        ctx.fillRect(0, 0, canvas.width, canvas.height)
        ctx.drawImage(img, 0, 0)

        const base64Content = canvas.toDataURL("image/png").split(",")[1]

        // ارسال به Flutter (کاربر می‌تواند PNG را به PDF تبدیل کند)
        if (window.FileDownloader) {
          const message = `${base64Content}|${filename}|pdf`
          window.FileDownloader.postMessage(message)
        }
      }

      img.onerror = () => {
        alert("خطا: نمودار قابل تبدیل نیست")
      }

      img.src = "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svgData)))
    } catch (error) {
      console.error("خطا در دانلود PDF:", error)
      alert(`خطا: ${error.message}`)
    }
  }

  // Auto-initialize download buttons
  document.addEventListener("DOMContentLoaded", () => {
    // دنبال کردن دکمه‌های دانلود موجود
    document.querySelectorAll("[data-download-format]").forEach((button) => {
      const format = button.getAttribute("data-download-format")
      const filename = button.getAttribute("data-filename") || `chart.${format}`

      button.addEventListener("click", (e) => {
        e.preventDefault()

        if (format === "svg") {
          window.downloadChartSVG(filename)
        } else if (format === "png") {
          window.downloadChartPNG(filename)
        } else if (format === "pdf") {
          window.downloadChartPDF(filename)
        }
      })
    })
  })

  console.log("[v0] Chart Download Helper loaded successfully")
})()
