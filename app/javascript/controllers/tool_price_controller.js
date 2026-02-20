document.addEventListener('DOMContentLoaded', function () {
  if (window.Stimulus) {
    window.Stimulus.register("tool-price", class extends window.Stimulus.Controller {
      connect() {
        const findFields = () => {
          const form = this.element.closest('form') || document.querySelector('form')
          if (!form) return { nameSelect: null, priceInput: null }
          const nameSelect = form.querySelector('select[name*="name"]') || form.querySelector('select[id*="name"]')
          const priceInput = form.querySelector('input[name*="price"]') || form.querySelector('input[id*="price"]')
          return { nameSelect, priceInput }
        }

        const setupPriceUpdate = (prices) => {
          const { nameSelect, priceInput } = findFields()
          if (!nameSelect || !priceInput) return false
          const updatePrice = () => {
            const selectedName = nameSelect.value
            if (selectedName && prices[selectedName] !== undefined) {
              priceInput.value = prices[selectedName]
              priceInput.dispatchEvent(new Event("input", { bubbles: true }))
              priceInput.dispatchEvent(new Event("change", { bubbles: true }))
            }
          }
          nameSelect.addEventListener('change', updatePrice)
          if (nameSelect.value) updatePrice()
          return true
        }

        const run = (prices) => {
          if (!setupPriceUpdate(prices)) setTimeout(() => run(prices), 200)
        }

        fetch('/api/v1/tools')
          .then(res => res.ok ? res.json() : Promise.reject(new Error('Failed to load tools')))
          .then(data => {
            const tools = data.data && data.data.tools
            if (!Array.isArray(tools)) return
            const prices = {}
            tools.forEach(t => { prices[t.name] = t.default_price })
            run(prices)
          })
          .catch(() => run({}))
      }
    })
  }
})
