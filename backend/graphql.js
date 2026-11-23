const {
    GraphQLObjectType,
    GraphQLSchema,
    GraphQLString,
    GraphQLInt,
    GraphQLFloat,
    GraphQLNonNull,
    GraphQLError
} = require('graphql');

const { createHandler } = require('graphql-http/lib/use/express');
const jwt = require('jsonwebtoken');

// ==================================================
// GRAPHQL TYPES
// ==================================================

const TaskType = new GraphQLObjectType({
    name: 'Task',

    fields: {
        taskId: {
            type: new GraphQLNonNull(GraphQLString)
        },
        title: {
            type: new GraphQLNonNull(GraphQLString)
        },
        description: {
            type: GraphQLString
        },
        subject: {
            type: GraphQLString
        },
        priority: {
            type: GraphQLString
        },
        status: {
            type: new GraphQLNonNull(GraphQLString)
        },
        dueDate: {
            type: GraphQLString
        },
        createdAt: {
            type: new GraphQLNonNull(GraphQLString)
        }
    }
});

const ResourceType = new GraphQLObjectType({
    name: 'Resource',

    fields: {
        resourceId: {
            type: new GraphQLNonNull(GraphQLString)
        },
        userId: {
            type: new GraphQLNonNull(GraphQLString)
        },
        title: {
            type: new GraphQLNonNull(GraphQLString)
        },
        description: {
            type: GraphQLString
        },
        category: {
            type: GraphQLString
        },
        resourceType: {
            type: new GraphQLNonNull(GraphQLString)
        },
        resourceUrl: {
            type: new GraphQLNonNull(GraphQLString)
        },
        visibility: {
            type: new GraphQLNonNull(GraphQLString)
        },
        createdAt: {
            type: new GraphQLNonNull(GraphQLString)
        },
        averageRating: {
            type: new GraphQLNonNull(GraphQLFloat)
        },
        ratingCount: {
            type: new GraphQLNonNull(GraphQLInt)
        },
        userRating: {
            type: GraphQLInt
        }
    }
});

const TaskPaginationType = new GraphQLObjectType({
    name: 'TaskPagination',

    fields: {
        currentPage: {
            type: new GraphQLNonNull(GraphQLInt)
        },
        totalPages: {
            type: new GraphQLNonNull(GraphQLInt)
        },
        totalTasks: {
            type: new GraphQLNonNull(GraphQLInt)
        },
        limit: {
            type: new GraphQLNonNull(GraphQLInt)
        },
        tasks: {
            type: new GraphQLNonNull(
                new (require('graphql').GraphQLList)(
                    new GraphQLNonNull(TaskType)
                )
            )
        }
    }
});

// ==================================================
// HELPER FUNCTIONS
// ==================================================

function requireAuthentication(context) {
    if (!context.userId) {
        throw new GraphQLError(
            'Authentication required. Please log in.',
            {
                extensions: {
                    code: 'UNAUTHENTICATED'
                }
            }
        );
    }

    return context.userId;
}

function formatTask(row) {
    return {
        taskId: String(row.task_id),
        title: row.title,
        description: row.description,
        subject: row.subject,
        priority: row.priority,
        status: row.status,
        dueDate: row.due_date
            ? row.due_date.toISOString()
            : null,
        createdAt: row.created_at.toISOString()
    };
}

function formatResource(row) {
    return {
        resourceId: String(row.resource_id),
        userId: String(row.user_id),
        title: row.title,
        description: row.description,
        category: row.category,
        resourceType: row.resource_type,
        resourceUrl: row.resource_url,
        visibility: row.visibility,
        createdAt: row.created_at.toISOString(),
        averageRating: Number(row.average_rating),
        ratingCount: Number(row.rating_count),
        userRating: row.user_rating === null
            ? null
            : Number(row.user_rating)
    };
}

// ==================================================
// GRAPHQL QUERIES
// ==================================================

const RootQuery = new GraphQLObjectType({
    name: 'RootQueryType',

    fields: {

        // ------------------------------------------
        // GET PAGINATED TASKS
        // ------------------------------------------

        tasks: {
            type: new GraphQLNonNull(TaskPaginationType),

            args: {
                page: {
                    type: GraphQLInt,
                    defaultValue: 1
                },
                limit: {
                    type: GraphQLInt,
                    defaultValue: 2
                }
            },

            resolve: async (_, args, context) => {
                const userId = requireAuthentication(context);

                const page = Math.max(
                    1,
                    Number.isInteger(args.page) ? args.page : 1
                );

                const limit = Math.min(
                    50,
                    Math.max(
                        1,
                        Number.isInteger(args.limit) ? args.limit : 2
                    )
                );

                const offset = (page - 1) * limit;

                const countResult = await context.pool.query(
                    `SELECT COUNT(*) AS total
                     FROM tasks
                     WHERE user_id = $1`,
                    [userId]
                );

                const totalTasks = Number(
                    countResult.rows[0].total
                );

                const totalPages = Math.ceil(totalTasks / limit);

                const result = await context.pool.query(
                    `SELECT *
                     FROM tasks
                     WHERE user_id = $1
                     ORDER BY task_id DESC
                     LIMIT $2 OFFSET $3`,
                    [userId, limit, offset]
                );

                return {
                    currentPage: page,
                    totalPages,
                    totalTasks,
                    limit,
                    tasks: result.rows.map(formatTask)
                };
            }
        },

        // ------------------------------------------
        // GET RESOURCES AND RATING STATISTICS
        // ------------------------------------------

        resources: {
            type: new (require('graphql').GraphQLList)(
                new GraphQLNonNull(ResourceType)
            ),

            resolve: async (_, args, context) => {
                const userId = requireAuthentication(context);

                const result = await context.pool.query(
                    `SELECT
                        r.resource_id,
                        r.user_id,
                        r.title,
                        r.description,
                        r.category,
                        r.resource_type,
                        r.resource_url,
                        r.visibility,
                        r.created_at,

                        COALESCE(
                            ROUND(AVG(rt.rating_value)::numeric, 2),
                            0
                        ) AS average_rating,

                        COUNT(rt.rating_id)::integer AS rating_count,

                        MAX(rt.rating_value) FILTER (
                            WHERE rt.user_id = $1
                        ) AS user_rating

                     FROM resources r

                     LEFT JOIN ratings rt
                        ON rt.resource_id = r.resource_id

                     WHERE r.visibility = 'public'
                        OR r.user_id = $1

                     GROUP BY r.resource_id

                     ORDER BY r.created_at DESC`,
                    [userId]
                );

                return result.rows.map(formatResource);
            }
        }
    }
});

// ==================================================
// GRAPHQL SCHEMA
// ==================================================

const schema = new GraphQLSchema({
    query: RootQuery
});

// ==================================================
// EXPRESS GRAPHQL HANDLER
// ==================================================

function createGraphQLHandler(pool, jwtSecret) {

    return createHandler({
        schema,

        context: (req) => {
            let userId = null;

            const authHeader = req.raw.headers.authorization;
            const token = authHeader && authHeader.split(' ')[1];

            if (token) {
                try {
                    const user = jwt.verify(token, jwtSecret);
                    userId = user.userId;
                } catch (error) {
                    userId = null;
                }
            }

            return {
                pool,
                userId
            };
        }
    });
}

module.exports = createGraphQLHandler;