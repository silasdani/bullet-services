document.addEventListener('DOMContentLoaded', function () {
  if (window.Stimulus) {
    window.Stimulus.register("tool-price", class extends window.Stimulus.Controller {
      connect() {
        const prices = {
          'No Works Required': 0,
          '½ set epoxy resin': 90,
          '1 set epoxy resin': 150,
          '2 sets epoxy resin': 300,
          '3 sets epoxy resin': 450,
          '500mm timber splice repair': 90,
          '1000mm timber splice repair': 150,
          'Conservation joint repair': 10,
          'Easing and adjusting of sash window': 100,
          'Front face repair to timber cill': 225,
          'New bottom rail to window casement': 130,
          'New glazing panel': 275,
          'New timber cill complete': 285,
          'New timber sash complete': 375,
          'Replacement sash cords': 100,
          'Splice repair to window jamb': 100,
          'Whole tube of epoxy resin': 150
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
