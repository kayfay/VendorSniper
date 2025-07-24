# VendorSniper

A WoW Classic addon that automatically scans the Auction House to find items that can be bought and vendored for profit, using BetterVendorPrice data.

## Features

- **Automated Scanning**: Automatically searches through 40+ common item categories
- **Real-time Results**: Items appear as they're found during scanning
- **Progress Tracking**: Visual progress bar shows scan completion percentage
- **Profit Calculation**: Compares auction prices with vendor prices for accurate profit margins
- **BetterVendorPrice Integration**: Uses BetterVendorPrice addon for accurate vendor price data
- **Clean UI**: Integrated tab in the Auction House interface
- **Sortable Results**: Items sorted by profit percentage (highest first)

## Installation

1. Download or clone this repository
2. Extract the `VendorSniper` folder to your WoW Classic `Interface/AddOns/` directory
3. Ensure you have [BetterVendorPrice](https://www.curseforge.com/wow/addons/better-vendor-price) installed for vendor price data
4. Restart WoW Classic or reload your UI (`/reload`)

## Usage

1. Open the Auction House
2. Click the "VendorSniper" tab (4th tab)
3. Click "Start Scan" to begin the automated scanning process
4. Watch the progress bar and real-time results as items are found
5. Click on any item row to see detailed tooltip information
6. Use the scroll bar to view all found items

## How It Works

VendorSniper automatically searches for profitable vendor opportunities by:

1. **Scanning Item Categories**: Searches through cloth, herbs, ores, leather, and other common materials
2. **Price Comparison**: Compares auction house buyout prices with vendor prices
3. **Profit Calculation**: Identifies items where auction price < vendor price
4. **Real-time Display**: Shows profitable items immediately as they're found
5. **Smart Sorting**: Displays items sorted by profit percentage

## Configuration

The addon includes several configurable options in `core.lua`:

- `minProfitThreshold`: Minimum profit in copper to show item (default: 1)
- `maxItemsToShow`: Maximum items to display (default: 50)
- `scanDelay`: Delay between searches in seconds (default: 0.5)
- `searchTerms`: List of item categories to search

## Dependencies

- **BetterVendorPrice**: Required for vendor price data
- **WoW Classic**: Compatible with Classic Era and Wrath Classic

## Screenshots

The addon adds a custom tab to the Auction House with:
- Start/Stop scan button
- Progress bar showing scan completion
- Real-time results table with columns for:
  - Item name
  - Auction price
  - Vendor price
  - Profit amount
  - Profit percentage

## Contributing

Feel free to submit issues, feature requests, or pull requests to improve the addon.

## License

This project is open source and available under the MIT License.

## Version

Current Version: 0.1 
