# frozen_string_literal: true

class HeroCarouselComponent < ApplicationComponent
  def initialize
    @slides = [
      {
        image: 'cover.jpg',
        image_large: 'madeleine-ragsdale-pJwH0MNXQp0-unsplash.jpg',
        title: 'We build<br>exteriors.'
      },
      {
        image: 'black-white-exterior-building.jpg',
        image_large: 'black-white-exterior-building.jpg',
        title: 'We build<br>exteriors.'
      },
      {
        image: 'madeleine-ragsdale-pJwH0MNXQp0-unsplash.jpg',
        image_large: 'cover.jpg',
        title: 'We build<br>exteriors.'
      }
    ]
  end

  private

  attr_reader :slides
end
