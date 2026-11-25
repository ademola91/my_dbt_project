[
  {
    $addFields:
      /**
       * newField: The new field name.
       * expression: The new field expression.
       */
      {
        ticket_week: {
          $dateTrunc: {
            date: {
              $dateFromString: {
                dateString: "$created_at"
              }
            },
            unit: "week",
            binSize: 1
          }
        }
      }
  },
  {
    $group:
      /**
       * _id: The id of the group.
       * fieldN: The first field name.
       */
      {
        _id: {
          week: "$ticket_week",
          category: "$category"
        },
        ticket_count: {
          $sum: 1
        },
        high_priority_count: {
          $sum: {
            $cond: [
              {
                $eq: ["$priority", "high"]
              },
              1,
              0
            ]
          }
        },
        escalated_count: {
          $sum: {
            $cond: [
              {
                $eq: ["$status", "escalated"]
              },
              1,
              0
            ]
          }
        }
      }
  },
  {
    $project:
      /**
       * specifications: The fields to
       *   include or exclude.
       */
      {
        _id: 0,
        ticket_week: "$_id.week",
        category: "$_id.category",
        ticket_count: 1,
        high_priority_count: 1,
        escalated_count: 1
      }
  },
  {
    $sort:
      /**
       * Provide any number of field/order pairs.
       */
      {
        ticket_week: 1,
        category: 1
      }
  }
]