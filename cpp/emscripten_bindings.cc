// Copyright 2013 The CARFAC Authors. All Rights Reserved.
// Author: Ron Weiss
//
// This file is part of an implementation of Lyon's cochlear model:
// "Cascade of Asymmetric Resonators with Fast-Acting Compression"
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#if EMSCRIPTEN
#include <emscripten/bind.h>
#endif
#include <SDL/SDL.h>

#include <cmath>
#include <memory>

#include "agc.h"
#include "car.h"
#include "carfac.h"
#include "ihc.h"
#include "sai.h"

using namespace emscripten;

// Helper class to run CARFAC, compute SAI frames, and plot them using
// SDL.  The interface is designed to be easy to interact with from
// Javascript when compiled using emscripten.
class SAIPlotter {
 public:
  explicit SAIPlotter(float sample_rate, int num_samples_per_segment) {
    constexpr int kNumEars = 1;
    CARParams car_params;
    IHCParams ihc_params;
    AGCParams agc_params;
    carfac_.reset(new CARFAC(kNumEars, sample_rate, car_params, ihc_params,
                             agc_params));
    // Only store NAP outputs.
    carfac_output_buffer_.reset(new CARFACOutput(true, false, false, false));

    sai_params_.num_channels = carfac_->num_channels();
    sai_params_.sai_width = num_samples_per_segment;
    sai_params_.input_segment_width = num_samples_per_segment;
    sai_params_.trigger_window_width = sai_params_.input_segment_width + 1;
    // Half of the SAI should come from the future.
    sai_params_.future_lags = sai_params_.sai_width / 2;
    sai_params_.num_triggers_per_frame = 2;
    sai_.reset(new SAI(sai_params_));
    sai_output_buffer_.reset(new ArrayXX(sai_params_.num_channels,
                                         sai_params_.sai_width));

    SDL_Init(SDL_INIT_VIDEO);
    screen_ = SDL_SetVideoMode(sai_params_.sai_width, carfac_->num_channels(),
                               32 /* bits_per_pixel */, SDL_SWSURFACE);
  }

  void Reset() {
    carfac_->Reset();
    sai_->Reset();
  }

  // Runs the given (single channel) audio samples through the CARFAC
  // filterbank, computes an SAI, and plots the result.
  //
  // The input_samples pointer type is chosen to avoid emscripten
  // compilation errors.
  // TODO(ronw): Figure out if this is the best way to pass a
  // javascript FloatArray to a C++ function using emscripten.
  void ComputeAndPlotSAI(intptr_t input_samples, size_t num_input_samples) {
    CARFAC_ASSERT(num_input_samples == sai_params_.input_segment_width);
    constexpr int kNumInputEars = 1;
    auto input_map = ArrayXX::Map(reinterpret_cast<const float*>(input_samples),
                                  kNumInputEars, num_input_samples);
    carfac_->RunSegment(input_map, false /* open_loop */,
                        carfac_output_buffer_.get());
    sai_->RunSegment(carfac_output_buffer_->nap()[0], sai_output_buffer_.get());
    PlotMatrix(*sai_output_buffer_);
  }

 private:
  // Plots the given matrix.  This assumes that the values of matrix
  // are within (0, 1), and clips values outside of this range.
  // Emscripten renders the output to an HTML5 canvas element.
  void PlotMatrix(const ArrayXX& matrix) {
    SDL_LockSurface(screen_);
    Uint32* pixels = static_cast<Uint32*>(screen_->pixels);
    for (int row = 0; row < matrix.rows(); ++row) {
      for (int col = 0; col < matrix.cols(); ++col) {
        Uint8 gray_value = 255 * (1.0 - fmin(fmax(matrix(row, col), 0.0), 1.0));
        pixels[(row * screen_->w) + col] =
          SDL_MapRGB(screen_->format, gray_value, gray_value, gray_value);
      }
    }
    SDL_UnlockSurface(screen_);
    SDL_Flip(screen_);
  }

  std::unique_ptr<CARFAC> carfac_;
  std::unique_ptr<CARFACOutput> carfac_output_buffer_;
  SAIParams sai_params_;
  std::unique_ptr<SAI> sai_;
  std::unique_ptr<ArrayXX> sai_output_buffer_;
  SDL_Surface* screen_;
};

#if EMSCRIPTEN
EMSCRIPTEN_BINDINGS(SAIPlotter) {
  register_vector<float>("FloatVector");
  class_<SAIPlotter>("SAIPlotter")
    .constructor<float, int>()
    .function("Reset", &SAIPlotter::Reset)
    .function("ComputeAndPlotSAI", &SAIPlotter::ComputeAndPlotSAI)
    ;
}
#endif