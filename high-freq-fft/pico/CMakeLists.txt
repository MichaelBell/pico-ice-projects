cmake_minimum_required(VERSION 3.13)

# import the pico-sdk
include(pico_sdk_import.cmake)

# configure the pico-sdk project
project(pico_fft C CXX ASM)
pico_sdk_init()

# add the pico-ice-sdk
add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/pico-ice-sdk/)

# add the local files
add_executable(${CMAKE_PROJECT_NAME}
    main.c
    usb_descriptors.c
    logic_analyser.c
    st7789_lcd.c
    )
target_link_libraries(${CMAKE_PROJECT_NAME}
    pico_ice_sdk
    pico_ice_usb
    pico_stdio_usb
    pico_multicore
    hardware_adc
    hardware_pwm
    )
target_include_directories(${CMAKE_PROJECT_NAME} PUBLIC
    ${CMAKE_CURRENT_LIST_DIR}
    )
pico_add_extra_outputs(${CMAKE_PROJECT_NAME})
pico_enable_stdio_usb(${CMAKE_PROJECT_NAME} 0)
pico_enable_stdio_uart(${CMAKE_PROJECT_NAME} 0)

pico_generate_pio_header(${CMAKE_PROJECT_NAME} ${CMAKE_CURRENT_LIST_DIR}/fft.pio)
pico_generate_pio_header(${CMAKE_PROJECT_NAME} ${CMAKE_CURRENT_LIST_DIR}/st7789_lcd.pio)