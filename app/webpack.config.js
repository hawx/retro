const CleanWebpackPlugin = require('clean-webpack-plugin');
const ExtractTextPlugin = require('extract-text-webpack-plugin');
const path = require('path');

module.exports = {
  entry: path.join(__dirname, 'index.js'),

  output: {
    path: path.join(__dirname, 'dist'),
    filename: 'index.js'
  },

  resolve: {
    modules: ['node_modules'],
    extensions: ['.js', '.elm']
  },

  module: {
    rules: [
      {
        test: /\.html$/,
        exclude: /node_modules/,
        use: ['file-loader?name=[name].[ext]']
      },
      {
        test: /\.(css|s[ac]ss)$/,
        use: ExtractTextPlugin.extract({
          fallback: 'style-loader',
          use: ['css-loader', 'sass-loader']
        })
      },
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        use: ['elm-hot-loader', 'elm-webpack-loader']
      }
    ],

    noParse: /\.elm$/
  },

  plugins: [
    new CleanWebpackPlugin(['dist'], {
      root: __dirname,
      verbose: true,
      dry: false
    }),
    new ExtractTextPlugin('styles.css', {
      allChunks: true
    })
  ],

  devServer: {
    historyApiFallback: true,
    stats: 'errors-only'
  }
};
