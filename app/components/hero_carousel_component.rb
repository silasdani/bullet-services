# frozen_string_literal: true

class HeroCarouselComponent < ApplicationComponent
  def initialize
    super
    @slides = [
      {
        image: 'cover.jpg',
        image_large: 'spacejoy-IH7wPsjwomc-unsplash.jpg',
        title: 'We build<br>exteriors.'
      },
      {
        image: 'asia-culturecenter-GupQWNEkBNc-unsplash.jpg',
        image_large: 'asia-culturecenter-GupQWNEkBNc-unsplash.jpg',
        title: 'We build<br>exteriors.'
      },
      {
        image: 'spacejoy-IH7wPsjwomc-unsplash.jpg',
        image_large: 'cover.jpg',
        title: 'We build<br>exteriors.'
      }
    ]
  end

  private

  attr_reader :slides
end
