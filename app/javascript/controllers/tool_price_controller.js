document.addEventListener('DOMContentLoaded', function () {
  if (window.Stimulus) {
    window.Stimulus.register("tool-price", class extends window.Stimulus.Controller {
      connect() {
        const prices = {
          'No Works Required': 0,
          '½ set epoxy resin': 60,
          '1 set epoxy resin': 100,
          '2 sets epoxy resin': 200,
          '3 sets epoxy resin': 300,
          '500mm timber splice repair': 70,
          '1000mm timber splice repair': 120,
          'Conservation joint repair': 25,
          'Easing and adjusting of sash window': 288,
          'Front face repair to timber cill': 221,
          'New bottom rail to window casement': 221,
          'New glazing panel': 288,
          'New timber cill complete': 221,
          'New timber sash complete': 1210,
          'Replacement sash cords': 144,
          'Splice repair to window jamb': 145,
          'Whole tube of epoxy resin': 100
        }

        const findFields = () => {
          const form = this.element.closest('form') || document.querySelector('form')
          if (!form) return { nameSelect: null, priceInput: null }

          const nameSelect = form.querySelector('select[name*="name"]') ||
            form.querySelector('select[id*="name"]')

          const priceInput = form.querySelector('input[name*="price"]') ||
            form.querySelector('input[id*="price"]')

          return { nameSelect, priceInput }
        }

        const setupPriceUpdate = () => {
          const { nameSelect, priceInput } = findFields()

          if (nameSelect && priceInput) {
            const updatePrice = () => {
              const selectedName = nameSelect.value
              if (selectedName && prices[selectedName] !== undefined) {
                priceInput.value = prices[selectedName]
                priceInput.dispatchEvent(new Event("input", { bubbles: true }))
                priceInput.dispatchEvent(new Event("change", { bubbles: true }))
              }
            }

            nameSelect.addEventListener('change', updatePrice)

            if (nameSelect.value) {
              updatePrice()
            }

            return true
          }
          return false
        }

        if (!setupPriceUpdate()) {
          setTimeout(() => {
            setupPriceUpdate()
          }, 200)
        }
      }
    })
  }
})
