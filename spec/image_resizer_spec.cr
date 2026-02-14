require "./spec_helper"

describe Tremolite::ImageResizer do
  describe ".processed_path_for_post" do
    it "generates JPEG path by default" do
      path = Tremolite::ImageResizer.processed_path_for_post(
        processed_path: "/images/processed",
        post_year: 2023,
        post_month: 7,
        post_slug: "2023-07-18-wycieczka",
        prefix: "article",
        file_name: "DSC00123.jpg"
      )
      path.should end_with(".jpg")
      path.should contain("article")
      path.should contain("DSC00123")
      path.should contain("2023")
      path.should contain("07")
    end

    it "generates AVIF path with format: avif" do
      path = Tremolite::ImageResizer.processed_path_for_post(
        processed_path: "/images/processed",
        post_year: 2023,
        post_month: 7,
        post_slug: "2023-07-18-wycieczka",
        prefix: "article",
        file_name: "DSC00123.jpg",
        format: "avif"
      )
      path.should end_with(".avif")
      path.should contain("article")
      path.should contain("DSC00123")
    end

    it "strips .jpg extension from file_name" do
      path = Tremolite::ImageResizer.processed_path_for_post(
        processed_path: "/images/processed",
        post_year: 2023,
        post_month: 5,
        post_slug: "slug",
        prefix: "grid",
        file_name: "photo.jpg"
      )
      path.should_not contain("photo.jpg")
      path.should contain("photo_grid.jpg")
    end

    it "strips .jpeg extension from file_name" do
      path = Tremolite::ImageResizer.processed_path_for_post(
        processed_path: "/images/processed",
        post_year: 2023,
        post_month: 5,
        post_slug: "slug",
        prefix: "grid",
        file_name: "photo.jpeg"
      )
      path.should_not contain("photo.jpeg")
      path.should contain("photo_grid.jpg")
    end

    it "strips .png extension from file_name" do
      path = Tremolite::ImageResizer.processed_path_for_post(
        processed_path: "/images/processed",
        post_year: 2023,
        post_month: 5,
        post_slug: "slug",
        prefix: "grid",
        file_name: "photo.png"
      )
      path.should_not contain("photo.png")
      path.should contain("photo_grid.jpg")
    end

    it "pads single-digit month with zero" do
      path = Tremolite::ImageResizer.processed_path_for_post(
        processed_path: "/images/processed",
        post_year: 2023,
        post_month: 3,
        post_slug: "slug",
        prefix: "card",
        file_name: "img.jpg"
      )
      path.should contain("/03/")
    end

    it "does not pad double-digit month" do
      path = Tremolite::ImageResizer.processed_path_for_post(
        processed_path: "/images/processed",
        post_year: 2023,
        post_month: 12,
        post_slug: "slug",
        prefix: "card",
        file_name: "img.jpg"
      )
      path.should contain("/12/")
    end

    it "AVIF and JPEG paths differ only in extension" do
      args = {
        processed_path: "/images/processed",
        post_year:      2023,
        post_month:     7,
        post_slug:      "2023-07-18-wycieczka",
        prefix:         "article",
        file_name:      "DSC00123.jpg",
      }
      jpeg_path = Tremolite::ImageResizer.processed_path_for_post(**args, format: "jpg")
      avif_path = Tremolite::ImageResizer.processed_path_for_post(**args, format: "avif")
      avif_path.sub(/\.avif$/, ".jpg").should eq jpeg_path
    end
  end
end
